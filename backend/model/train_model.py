"""Train a simple classifier for SoilSafe and save as a Pickle file.

This script creates a synthetic dataset if none provided and trains a pipeline
(OneHotEncoder for categoricals + RandomForestClassifier).
"""
import argparse
import os
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score, cross_val_predict
from sklearn.metrics import classification_report, confusion_matrix
import joblib
import datetime
import sklearn


def _aggregate_importances_from_pipe(pipe, clf_name='clf'):
    """Aggregate feature importances back to original input features for readability."""
    try:
        pre = pipe.named_steps['pre']
    except Exception:
        return {}
    try:
        feat_names = pre.get_feature_names_out()
    except Exception:
        # fallback simple naming
        feat_names = []
    try:
        clf = pipe.named_steps[clf_name]
        imps = clf.feature_importances_
    except Exception:
        return {}
    agg = {}
    for name, imp in zip(feat_names, imps):
        if 'soil_type' in name:
            key = 'soil_type'
        elif 'elevation_category' in name:
            key = 'elevation_category'
        elif 'flood_frequency' in name or name.startswith('flood_frequency'):
            key = 'flood_frequency'
        elif 'rainfall_intensity' in name or name.startswith('rainfall_intensity'):
            key = 'rainfall_intensity'
        elif 'distance_from_river' in name or name.startswith('distance_from_river'):
            key = 'distance_from_river'
        else:
            key = name
        agg[key] = agg.get(key, 0.0) + float(imp)
    total = sum(agg.values()) or 1.0
    for k in list(agg.keys()):
        agg[k] = float(agg[k] / total)
    return agg


def make_synthetic_dataset(path=None, n=1000, random_state=42):
    rng = np.random.RandomState(random_state)
    soil_types = ["clay", "silt", "sand", "loam"]
    elevation = ["low", "mid", "high"]
    rows = []
    for _ in range(n):
        st = rng.choice(soil_types)
        ff = rng.poisson(2)
        ri = max(0, rng.normal(80, 30))
        ec = rng.choice(elevation, p=[0.4, 0.35, 0.25])
        dfr = round(abs(rng.normal(2.0, 2.5)), 2)

        # simple heuristic to set risk label (for demo purposes)
        score = 0
        if st in ("clay", "silt"): score += 1
        score += int(ff >= 3)
        score += int(ri >= 100)
        score += (0 if ec == "high" else 1)
        score += int(dfr < 1.0)

        if score >= 4:
            label = "High"
        elif score >= 2:
            label = "Medium"
        else:
            label = "Low"

        # infer categorical rainfall bucket for synthetic record
        if ri < 20:
            rc = 'Light'
        elif ri <= 100:
            rc = 'Moderate'
        else:
            rc = 'Heavy'

        rows.append({
            "soil_type": st,
            "flood_frequency": ff,
            "rainfall_intensity": ri,
            "elevation_category": ec,
            "distance_from_river": dfr,
            "rainfall_category": rc,
            "risk_label": label,
        })

    df = pd.DataFrame(rows)
    if path:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        df.to_csv(path, index=False)
    return df


def train_and_save(output_path: str, data_path: str = None):
    if data_path and os.path.exists(data_path):
        df = pd.read_csv(data_path)
        # Accept both 'label' and 'risk_label' as target column
        if 'label' in df.columns and 'risk_label' not in df.columns:
            df = df.rename(columns={'label': 'risk_label'})
    else:
        print("No dataset found or path not provided. Generating synthetic dataset...")
        df = make_synthetic_dataset(n=2000)

    if 'risk_label' not in df.columns:
        raise ValueError('Dataset must include a target column named "risk_label" or "label"')

    X = df.drop(columns=["risk_label"])
    y = df["risk_label"]

    cat_cols = ["soil_type", "elevation_category"]
    num_cols = ["flood_frequency", "rainfall_intensity", "distance_from_river"]

    pre = ColumnTransformer([
        ("cat", OneHotEncoder(handle_unknown="ignore"), cat_cols),
        ("num", StandardScaler(), num_cols),
    ])

    # show class distribution
    class_counts = y.value_counts().to_dict()
    print(f"Class distribution: {class_counts}")

    rf_pipe = Pipeline([
        ("pre", pre),
        ("clf", RandomForestClassifier(n_estimators=200, random_state=42, class_weight='balanced'))
    ])

    dt_pipe = Pipeline([
        ("pre", pre),
        ("clf", DecisionTreeClassifier(max_depth=6, random_state=42, class_weight='balanced'))
    ])

    # Cross-validation to estimate generalization
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    print("Running cross-validation (StratifiedKFold=5)...")
    rf_cv_scores = cross_val_score(rf_pipe, X, y, cv=skf, scoring='balanced_accuracy')
    dt_cv_scores = cross_val_score(dt_pipe, X, y, cv=skf, scoring='balanced_accuracy')
    print(f"RF CV balanced_accuracy: mean={rf_cv_scores.mean():.4f}, std={rf_cv_scores.std():.4f}")
    print(f"DT CV balanced_accuracy: mean={dt_cv_scores.mean():.4f}, std={dt_cv_scores.std():.4f}")

    # Cross-validated predictions for aggregated report
    rf_cv_preds = cross_val_predict(rf_pipe, X, y, cv=skf)
    dt_cv_preds = cross_val_predict(dt_pipe, X, y, cv=skf)

    print("Cross-validated RandomForest report:\n", classification_report(y, rf_cv_preds))
    print("Cross-validated DecisionTree report:\n", classification_report(y, dt_cv_preds))
    print("RandomForest confusion matrix:\n", confusion_matrix(y, rf_cv_preds))

    # final train/test split and fit final models
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    rf_pipe.fit(X_train, y_train)
    dt_pipe.fit(X_train, y_train)

    rf_preds = rf_pipe.predict(X_test)
    dt_preds = dt_pipe.predict(X_test)

    test_report_rf = classification_report(y_test, rf_preds)
    test_report_dt = classification_report(y_test, dt_preds)

    print("RandomForest performance on hold-out test:\n", test_report_rf)
    print("DecisionTree performance on hold-out test:\n", test_report_dt)

    # compute aggregated importances for readability
    rf_imps = _aggregate_importances_from_pipe(rf_pipe, clf_name='clf')
    dt_imps = _aggregate_importances_from_pipe(dt_pipe, clf_name='clf')

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    # Save both pipelines plus metadata
    artifact = {
        'rf': rf_pipe,
        'dt': dt_pipe,
        'feature_importances': {
            'random_forest': rf_imps,
            'decision_tree': dt_imps
        },
        'training_details': {
            'data_path': data_path or 'synthetic',
            'n_samples': int(X.shape[0]),
            'class_counts': class_counts,
            'used_rainfall_category': 'rainfall_category' in df.columns,
            'rf_cv_scores': rf_cv_scores.tolist(),
            'dt_cv_scores': dt_cv_scores.tolist(),
            'rf_test_report': test_report_rf,
            'dt_test_report': test_report_dt,
            'timestamp': datetime.datetime.utcnow().isoformat() + 'Z',
            'sklearn_version': sklearn.__version__,
        }
    }

    joblib.dump(artifact, output_path)
    print(f"Saved model artifact (RF + DT) to {output_path}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", type=str, default="model/soil_model.pkl")
    ap.add_argument("--data", type=str, default="data/dataset.csv")
    args = ap.parse_args()

    train_and_save(args.output, args.data)
