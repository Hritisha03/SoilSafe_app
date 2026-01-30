"""Train a simple classifier for SoilSafe and save as a Pickle file.

This script creates a synthetic dataset if none provided and trains a pipeline
(OneHotEncoder for categoricals + RandomForestClassifier).
"""
import argparse
import os
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib


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

        rows.append({
            "soil_type": st,
            "flood_frequency": ff,
            "rainfall_intensity": ri,
            "elevation_category": ec,
            "distance_from_river": dfr,
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
    else:
        print("No dataset found or path not provided. Generating synthetic dataset...")
        df = make_synthetic_dataset(n=2000)

    X = df.drop(columns=["risk_label"])
    y = df["risk_label"]

    cat_cols = ["soil_type", "elevation_category"]
    num_cols = ["flood_frequency", "rainfall_intensity", "distance_from_river"]

    pre = ColumnTransformer([
        ("cat", OneHotEncoder(handle_unknown="ignore"), cat_cols),
        ("num", StandardScaler(), num_cols),
    ])

    pipe = Pipeline([
        ("pre", pre),
        ("clf", RandomForestClassifier(n_estimators=150, random_state=42))
    ])

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    pipe.fit(X_train, y_train)
    preds = pipe.predict(X_test)
    print(classification_report(y_test, preds))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    joblib.dump(pipe, output_path)
    print(f"Saved model to {output_path}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", type=str, default="model/soil_model.pkl")
    ap.add_argument("--data", type=str, default="data/dataset.csv")
    args = ap.parse_args()

    train_and_save(args.output, args.data)
