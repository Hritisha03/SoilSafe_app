"""Flask API for SoilSafe

Endpoints:
- GET /health
- POST /api/v1/predict (new versioned endpoint)
- POST /predict (backward compatible, calls v1)

Return structured JSON risk predictions.
"""
from flask import Flask, request, jsonify
import joblib
import os
import traceback


try:
    from flask_cors import CORS
except ImportError:
    def CORS(app):
        pass

# Prefer the default model path near this module if it exists (robust against env var mistakes)
_default_model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "model/soil_model.pkl"))
_env_model = os.environ.get("SOIL_MODEL_PATH")
if os.path.exists(_default_model_path):
    MODEL_PATH = _default_model_path
elif _env_model:
    # If env var provided, resolve both absolute and relative candidates
    cand1 = os.path.abspath(_env_model)
    cand2 = os.path.abspath(os.path.join(os.path.dirname(__file__), _env_model))
    if os.path.exists(cand1):
        MODEL_PATH = cand1
    elif os.path.exists(cand2):
        MODEL_PATH = cand2
    else:
        # fallback to cand1 (absoluteified env var)
        MODEL_PATH = cand1
else:
    MODEL_PATH = _default_model_path

app = Flask(__name__)
CORS(app)

# Load model at startup (if available), and provide runtime reload if needed
model = None
if os.path.exists(MODEL_PATH):
    try:
        model = joblib.load(MODEL_PATH)
        app.logger.info(f"Loaded model from {MODEL_PATH}")
    except Exception as e:
        app.logger.error("Failed to load model: %s", e)
else:
    app.logger.warning("Model file not found. Run `python model/train_model.py` to create it.")


def _ensure_model_loaded():
    """Attempt to load the model at runtime if it wasn't available at startup."""
    global model
    if model is None and os.path.exists(MODEL_PATH):
        try:
            model = joblib.load(MODEL_PATH)
            app.logger.info(f"Runtime-loaded model from {MODEL_PATH}")
        except Exception as e:
            app.logger.error("Runtime model load failed: %s", e)



@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


def _aggregate_importances(pipe, pre, clf):
    """Aggregate feature importances back to original input features."""
    try:
        feat_names = pre.get_feature_names_out()
    except Exception:
        feat_names = pre.transformers_[0][2] + pre.transformers_[1][2]
    
    importances = clf.feature_importances_
    if len(feat_names) != len(importances):
        feat_names = [f"f{i}" for i in range(len(importances))]
    
    agg = {}
    for name, imp in zip(feat_names, importances):
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


def _simple_explanation(input_row, importances):
    """Generate human-readable explanation of top contributing factors."""
    parts = []
    # Sort by importance
    items = sorted(importances.items(), key=lambda x: x[1], reverse=True)
    top = items[:3]

    for f, imp in top:
        val = input_row.get(f)
        if f == 'soil_type':
            parts.append(f"Soil type '{val}' can affect post-flood stability.")
        elif f == 'flood_frequency':
            try:
                v = float(val)
                if v >= 3:
                    parts.append(f"Frequent flooding ({int(v)} times) increases saturation and erosion risk.")
                else:
                    parts.append(f"Flood occurrences ({int(v)} times) are a contributing factor.")
            except Exception:
                parts.append(f"Flood frequency ({val}) considered.")
        elif f == 'rainfall_intensity':
            try:
                v = float(val)
                if v >= 100:
                    parts.append(f"Heavy rainfall ({v:.0f} mm) raises landslip and saturation risk.")
                else:
                    parts.append(f"Rainfall intensity ({v:.0f} mm) influences soil moisture.")
            except Exception:
                parts.append(f"Rainfall ({val}) considered.")
        elif f == 'elevation_category':
            if val in ('low', 'mid'):
                parts.append(f"Lower elevation ('{val}') is more flood-prone and increases risk.")
            else:
                parts.append(f"Elevation ('{val}') provides some protection against flooding.")
        elif f == 'distance_from_river':
            try:
                v = float(val)
                if v < 1.0:
                    parts.append(f"Very close to river ({v} km) which raises flood exposure.")
                else:
                    parts.append(f"Distance from river ({v} km) affects exposure.")
            except Exception:
                parts.append(f"Distance from river ({val}) considered.")
    return ' '.join(parts)


def _recommendation_for_risk(risk_level):
    if risk_level.lower() == 'high':
        return (
            "High risk: Restrict access and seek a professional geotechnical inspection before re-using the land. Avoid heavy machinery and replanting until cleared."
        )
    if risk_level.lower() == 'medium':
        return (
            "Moderate risk: Schedule an inspection, reduce heavy loads, and monitor for settlement or waterlogging. Take precautions before replanting."
        )
    return (
        "Low risk: Routine checks recommended. Continue with caution and schedule a follow-up inspection if conditions change."
    )


# ---------------------------------------------------------------------------
# Location -> feature inference (prototype / rule-based)
# ---------------------------------------------------------------------------
import json

RULES_PATH = os.path.join(os.path.dirname(__file__), 'data/region_rules.json')
try:
    with open(RULES_PATH, 'r', encoding='utf8') as fh:
        REGION_RULES = json.load(fh)
        app.logger.info(f"Loaded {len(REGION_RULES)} region rules from {RULES_PATH}")
except Exception:
    REGION_RULES = []
    app.logger.warning("No region rules loaded; falling back to default heuristics.")


def _infer_features_from_location(lat, lon, region_name=None):
    """Infer soil/flood features from latitude/longitude using simple rules.
    Returns a dict suitable for model input and a chosen region name.
    """
    # Try rule matching by bounding box
    for r in REGION_RULES:
        try:
            if lat >= float(r.get('min_lat', -90)) and lat <= float(r.get('max_lat', 90)) and lon >= float(r.get('min_lon', -180)) and lon <= float(r.get('max_lon', 180)):
                return ({
                    'soil_type': r.get('soil_type', 'silt'),
                    'rainfall_intensity': float(r.get('rainfall_intensity', 100)),
                    'flood_frequency': float(r.get('flood_frequency', 1)),
                    'elevation_category': r.get('elevation_category', 'low'),
                    'distance_from_river': float(r.get('distance_from_river', 1.0)),
                }, r.get('name'))
        except Exception:
            continue

    # Fallback heuristics (simple north/south & coastal check)
    soil = 'silt'
    rainfall = 100.0
    flood_freq = 1.0
    elev = 'mid'
    dist = 2.0

    # Coastal proximity heuristic: if longitude is close to typical coastlines (simplified)
    if abs(lon) < 100 and (lat < 22 or lat > 8):
        soil = 'clay'
        rainfall = 180.0
        flood_freq = 3.0
        elev = 'low'
        dist = 0.5

    # Northern plains heuristic
    if lat >= 24 and lat <= 29:
        soil = 'silt'
        rainfall = 120.0
        flood_freq = 2.0
        elev = 'low'
        dist = 1.0

    # Hill heuristic
    if lat > 28:
        soil = 'sandy'
        rainfall = 80.0
        flood_freq = 1.0
        elev = 'high'
        dist = 3.0

    return ({
        'soil_type': soil,
        'rainfall_intensity': rainfall,
        'flood_frequency': flood_freq,
        'elevation_category': elev,
        'distance_from_river': dist,
    }, region_name)


@app.route('/api/v1/predict-location', methods=['POST'])
def predict_by_location():
    """Accepts JSON { latitude, longitude, region (optional) } and returns the same structured response as predict_v1.

    This endpoint derives approximate features from the provided coordinates using a rule-based mapping (for prototype/academic use only).
    """
    global model
    try:
        data = request.get_json(force=True)
        lat = data.get('latitude')
        lon = data.get('longitude')
        region_name = data.get('region')
        if lat is None or lon is None:
            return jsonify({'error': 'Missing latitude or longitude'}), 400

        try:
            lat = float(lat)
            lon = float(lon)
        except Exception:
            return jsonify({'error': 'Latitude and longitude must be numeric'}), 400

        # Derive features
        row_features, inferred_region = _infer_features_from_location(lat, lon, region_name)
        # attach metadata
        row_features_meta = dict(row_features)
        row_features_meta['latitude'] = lat
        row_features_meta['longitude'] = lon
        if inferred_region:
            row_features_meta['region'] = inferred_region

        # Build input and reuse same prediction logic as predict_v1
        import pandas as pd
        X = pd.DataFrame([{
            'soil_type': row_features['soil_type'],
            'flood_frequency': float(row_features['flood_frequency']),
            'rainfall_intensity': float(row_features['rainfall_intensity']),
            'elevation_category': row_features['elevation_category'],
            'distance_from_river': float(row_features.get('distance_from_river', 0.0)),
        }])

        _ensure_model_loaded()
        if model is None:
            return jsonify({"error": "Model not loaded. Train and save a model with model/train_model.py"}), 500

        if isinstance(model, dict):
            rf = model.get('rf')
            dt = model.get('dt')
            pre = rf.named_steps['pre'] if hasattr(rf, 'named_steps') else None
            rf_clf = rf.named_steps['clf'] if hasattr(rf, 'named_steps') else rf
            importances = _aggregate_importances(rf, pre, rf_clf) if pre is not None else {}
        else:
            rf = model
            dt = None
            pre = rf.named_steps['pre'] if hasattr(rf, 'named_steps') else None
            rf_clf = rf.named_steps['clf'] if hasattr(rf, 'named_steps') else rf
            importances = _aggregate_importances(rf, pre, rf_clf) if pre is not None else {}

        try:
            proba = rf.predict_proba(X)[0]
            classes = list(rf.classes_)
            probs = {c: float(p) for c, p in zip(classes, proba)}
            pred = rf.predict(X)[0]
            confidence = float(probs.get(pred, max(probs.values())))
        except Exception:
            pred = rf.predict(X)[0]
            probs = None
            confidence = 1.0

        dt_info = None
        agree = None
        if dt is not None:
            try:
                dt_pred = dt.predict(X)[0]
                try:
                    dt_proba = dt.predict_proba(X)[0]
                    dt_conf = float(dt_proba[list(dt.classes_).index(dt_pred)])
                except Exception:
                    dt_conf = 1.0
                dt_info = {"prediction": dt_pred, "confidence": dt_conf}
                agree = (str(dt_pred).lower() == str(pred).lower())
            except Exception:
                dt_info = None

        explanation = _simple_explanation(row_features, importances)
        explanation += " Predictions are indicative and based on regional data (prototype)."
        recommendation = _recommendation_for_risk(pred)

        fi_list = sorted([(k, float(v)) for k, v in importances.items()], key=lambda x: x[1], reverse=True)

        resp = {
            "risk_level": pred,
            "confidence": confidence,
            "probabilities": probs,
            "explanation": explanation,
            "recommendation": recommendation,
            "feature_importances": [{"feature": f, "importance": imp} for f, imp in fi_list],
            "influencing_factors": explanation.split('. '),
            "inferred_features": row_features_meta,
            "disclaimer": "Predictions are indicative and based on regional data. Not a substitute for on-site testing.",
        }
        if dt_info is not None:
            resp['model_comparison'] = {"decision_tree": dt_info, "agree": agree}

        if inferred_region:
            resp['region'] = inferred_region

        resp['location'] = {"latitude": lat, "longitude": lon}

        return jsonify(resp), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": "Server error", "details": str(e)}), 500


@app.route('/api/v1/predict', methods=['POST'])
def predict_v1():
    """Versioned predict endpoint. Returns structured JSON with explanation and recommendations."""
    global model
    try:
        data = request.get_json(force=True)
        # Validate basic inputs (distance_from_river optional)
        required = ["soil_type", "flood_frequency", "rainfall_intensity", "elevation_category"]
        for k in required:
            if k not in data:
                return jsonify({"error": f"Missing field: {k}"}), 400

        # Build input row
        import pandas as pd
        row = {
            "soil_type": data.get("soil_type"),
            "flood_frequency": float(data.get("flood_frequency")),
            "rainfall_intensity": float(data.get("rainfall_intensity")),
            "elevation_category": data.get("elevation_category"),
            "distance_from_river": float(data.get("distance_from_river", 0.0)),
        }
        X = pd.DataFrame([row])

        _ensure_model_loaded()
        if model is None:
            return jsonify({"error": "Model not loaded. Train and save a model with model/train_model.py"}), 500

        # Backwards-compatible model object handling
        if isinstance(model, dict):
            rf = model.get('rf')
            dt = model.get('dt')
            pre = rf.named_steps['pre'] if hasattr(rf, 'named_steps') else None
            rf_clf = rf.named_steps['clf'] if hasattr(rf, 'named_steps') else rf
            importances = _aggregate_importances(rf, pre, rf_clf) if pre is not None else {}
        else:
            # Older single-pipeline model
            rf = model
            dt = None
            pre = rf.named_steps['pre'] if hasattr(rf, 'named_steps') else None
            rf_clf = rf.named_steps['clf'] if hasattr(rf, 'named_steps') else rf
            importances = _aggregate_importances(rf, pre, rf_clf) if pre is not None else {}

        # Primary prediction (Random Forest)
        try:
            proba = rf.predict_proba(X)[0]
            classes = list(rf.classes_)
            probs = {c: float(p) for c, p in zip(classes, proba)}
            pred = rf.predict(X)[0]
            confidence = float(probs.get(pred, max(probs.values())))
        except Exception:
            pred = rf.predict(X)[0]
            probs = None
            confidence = 1.0

        # Decision tree comparison when available
        dt_info = None
        agree = None
        if dt is not None:
            try:
                dt_pred = dt.predict(X)[0]
                try:
                    dt_proba = dt.predict_proba(X)[0]
                    dt_conf = float(dt_proba[list(dt.classes_).index(dt_pred)])
                except Exception:
                    dt_conf = 1.0
                dt_info = {"prediction": dt_pred, "confidence": dt_conf}
                agree = (str(dt_pred).lower() == str(pred).lower())
            except Exception:
                dt_info = None

        explanation = _simple_explanation(row, importances)
        if data.get('region'):
            explanation += f" Region: {data.get('region')}."
        if data.get('latitude') and data.get('longitude'):
            explanation += " Location coordinates provided." 

        recommendation = _recommendation_for_risk(pred)

        # Prepare feature_importances list sorted
        fi_list = sorted([(k, float(v)) for k, v in importances.items()], key=lambda x: x[1], reverse=True)

        resp = {
            "risk_level": pred,
            "confidence": confidence,
            "probabilities": probs,
            "explanation": explanation,
            "recommendation": recommendation,
            "feature_importances": [{"feature": f, "importance": imp} for f, imp in fi_list],
            "influencing_factors": explanation.split('. ')
        }
        if dt_info is not None:
            resp['model_comparison'] = {"decision_tree": dt_info, "agree": agree}

        # include provided metadata
        if data.get('region'):
            resp['region'] = data.get('region')
        if data.get('latitude') and data.get('longitude'):
            try:
                resp['location'] = {"latitude": float(data.get('latitude')), "longitude": float(data.get('longitude'))}
            except Exception:
                resp['location'] = {"raw_lat": data.get('latitude'), "raw_lon": data.get('longitude')}

        return jsonify(resp), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": "Server error", "details": str(e)}), 500


# Backwards compatible route
@app.route("/predict", methods=["POST"])
def predict():
    # Simple wrapper for compatibility; call new v1 endpoint behavior
    return predict_v1()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
