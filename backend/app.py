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
import requests
from datetime import datetime, timedelta


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
                # Prefer categorical wording for clarity when available
                cat = None
                try:
                    cat = _rainfall_category_from_mm(v)
                except Exception:
                    pass
                if cat is not None:
                    if cat == 'Heavy':
                        parts.append(f"Heavy rainfall ({v:.0f} mm) raises landslip and saturation risk.")
                    elif cat == 'Moderate':
                        parts.append(f"Moderate rainfall ({v:.0f} mm) increases soil moisture and erosion potential.")
                    else:
                        parts.append(f"Light rainfall ({v:.0f} mm) less likely to cause acute saturation.")
                else:
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


def _lookup_region_rule(lat, lon):
    """Return a matching region rule dict or None"""
    for r in REGION_RULES:
        try:
            if lat >= float(r.get('min_lat', -90)) and lat <= float(r.get('max_lat', 90)) and lon >= float(r.get('min_lon', -180)) and lon <= float(r.get('max_lon', 180)):
                return r
        except Exception:
            continue
    return None


def _fetch_recent_rainfall_mm(lat, lon):
    """Fetch recent precipitation (mm) using Open-Meteo hourly precipitation.
    Returns (mm_total, 'source')
    """
    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
            "&hourly=precipitation&past_days=1&timezone=UTC"
        )
        r = requests.get(url, timeout=8)
        if r.status_code == 200:
            j = r.json()
            hourly = j.get('hourly', {})
            precip = hourly.get('precipitation', [])
            if precip:
                total = float(sum(precip))
                return (total, 'open-meteo')
    except Exception:
        app.logger.debug('Rainfall fetch failed', exc_info=True)
    return (None, 'fallback')


def _fetch_elevation_m(lat, lon):
    """Fetch elevation in meters using open-elevation (free service) or Open-Meteo fallback"""
    try:
        url = f"https://api.open-elevation.com/api/v1/lookup?locations={lat},{lon}"
        r = requests.get(url, timeout=6)
        if r.status_code == 200:
            j = r.json()
            results = j.get('results') or []
            if results:
                elev = results[0].get('elevation')
                if elev is not None:
                    return (float(elev), 'open-elevation')
    except Exception:
        app.logger.debug('Open-elevation failed', exc_info=True)
    # Try Open-Meteo as fallback (it often returns elevation in response)
    try:
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true"
        r = requests.get(url, timeout=6)
        if r.status_code == 200:
            j = r.json()
            elev = j.get('elevation')
            if elev is not None:
                return (float(elev), 'open-meteo')
    except Exception:
        app.logger.debug('Open-meteo elevation fetch failed', exc_info=True)
    return (None, 'fallback')


def _elevation_category_from_m(elev_m):
    if elev_m is None:
        return None
    if elev_m < 50:
        return 'low'
    if elev_m < 300:
        return 'mid'
    return 'high'


def _rainfall_category_from_mm(mm):
    """Map rainfall in mm (24h) to categorical buckets used for explanation.
    Thresholds (explainable):
      - Light: < 20 mm
      - Moderate: 20-100 mm
      - Heavy: >100 mm
    Keep thresholds simple and documented.
    """
    try:
        if mm is None:
            return None
        mm = float(mm)
        if mm < 20.0:
            return 'Light'
        if mm <= 100.0:
            return 'Moderate'
        return 'Heavy'
    except Exception:
        return None


def _generate_features_from_location(lat, lon):
    """Generate model-ready features by consulting real APIs and region rules.
    Returns (feature_dict, meta_info)
    """
    meta = {'sources': {}}

    # 1) Region rule lookup
    rule = _lookup_region_rule(lat, lon)

    # 2) Fetch rainfall (mm over past 24h)
    rainfall_mm, rainfall_src = _fetch_recent_rainfall_mm(lat, lon)
    meta['sources']['rainfall'] = rainfall_src

    # Map rainfall to numeric intensity if available
    if rainfall_mm is not None:
        rainfall_intensity = float(rainfall_mm)
    else:
        rainfall_intensity = None

    # Also derive a categorical rainfall bucket for explanation (Light/Moderate/Heavy)
    rainfall_category = _rainfall_category_from_mm(rainfall_intensity)
    if rainfall_category is not None:
        meta['rainfall_category'] = rainfall_category

    # 3) Elevation
    elev_m, elev_src = _fetch_elevation_m(lat, lon)
    meta['sources']['elevation'] = elev_src
    elev_cat = _elevation_category_from_m(elev_m)

    # 4) Flood frequency & soil type from rule or fallback heuristics
    flood_freq = None
    soil_type = None
    distance_from_river = None

    if rule is not None:
        try:
            flood_freq = float(rule.get('flood_frequency'))
        except Exception:
            flood_freq = None
        soil_type = rule.get('soil_type')
        distance_from_river = float(rule.get('distance_from_river', 1.0))
        meta['region'] = rule.get('name')
        meta['sources']['region_rule'] = rule.get('name')

    # Fallback heuristics when APIs or rules missing
    if rainfall_intensity is None:
        # Use rule value if available
        if rule is not None and rule.get('rainfall_intensity') is not None:
            rainfall_intensity = float(rule.get('rainfall_intensity'))
            meta['sources']['rainfall'] = 'region-rule'
        else:
            rainfall_intensity = 50.0
            meta['sources']['rainfall'] = 'default'

    if elev_cat is None:
        if rule is not None and rule.get('elevation_category') is not None:
            elev_cat = rule.get('elevation_category')
            meta['sources']['elevation'] = 'region-rule'
        else:
            elev_cat = 'mid'
            meta['sources']['elevation'] = 'default'

    if flood_freq is None:
        flood_freq = float(rule.get('flood_frequency', 1.0)) if rule is not None else 1.0
        meta['sources']['flood_frequency'] = 'region-rule' if rule is not None else 'default'

    if soil_type is None:
        soil_type = rule.get('soil_type', 'silt') if rule is not None else 'silt'
        meta['sources']['soil_type'] = 'region-rule' if rule is not None else 'default'

    if distance_from_river is None:
        distance_from_river = float(rule.get('distance_from_river', 2.0)) if rule is not None else 2.0
        meta['sources']['distance_from_river'] = 'region-rule' if rule is not None else 'default'

    features = {
        'soil_type': soil_type,
        'rainfall_intensity': float(rainfall_intensity),
        'flood_frequency': float(flood_freq),
        'elevation_category': elev_cat,
        'distance_from_river': float(distance_from_river),
        # Not used directly by current model but useful for explanations and potential retraining
        'rainfall_category': rainfall_category,
    }

    # Include raw measured elevation if available
    if elev_m is not None:
        meta['elevation_m'] = float(elev_m)

    return features, meta


@app.route('/api/v1/predict-location', methods=['POST'])
def predict_by_location():
    """Legacy compatibility endpoint: accepts JSON { latitude, longitude, region (optional) } and returns structured response.
    Delegates to the unified predict endpoint behavior but keeps the older path for existing clients."""
    data = request.get_json(force=True)
    # forward to new predict logic by embedding into a unified call
    lat = data.get('latitude')
    lon = data.get('longitude')
    if lat is None or lon is None:
        return jsonify({'error': 'Missing latitude or longitude'}), 400
    # reuse predict_v1 logic by creating a minimal payload
    return predict_v1()


# ---------------------------------------------------------------------------
# New unified predict endpoint: accepts either manual features or just lat/lon
# ---------------------------------------------------------------------------
@app.route('/api/v1/predict', methods=['POST'])
def predict_v1():
    """Versioned predict endpoint. Accepts either explicit features or only latitude/longitude.

    If latitude & longitude are provided, the backend will fetch environmental
    data (rainfall, elevation) and lookup regional flood/soil information.
    """
    global model
    try:
        data = request.get_json(force=True)
        app.logger.debug(f"Predict request data: {data}")

        # If lat/lon provided, generate features automatically
        lat = data.get('latitude')
        lon = data.get('longitude')
        if lat is not None and lon is not None:
            try:
                lat = float(lat); lon = float(lon)
            except Exception:
                return jsonify({'error': 'Latitude and longitude must be numeric'}), 400

            row_features, meta = _generate_features_from_location(lat, lon)
            row = {
                'soil_type': row_features['soil_type'],
                'flood_frequency': float(row_features['flood_frequency']),
                'rainfall_intensity': float(row_features['rainfall_intensity']),
                'elevation_category': row_features['elevation_category'],
                'distance_from_river': float(row_features.get('distance_from_river', 0.0)),
                'rainfall_category': row_features.get('rainfall_category')
            }
        else:
            # Backwards compatible manual inputs
            required = ['soil_type', 'flood_frequency', 'rainfall_intensity', 'elevation_category']
            for k in required:
                if k not in data:
                    return jsonify({'error': f'Missing field: {k}'}), 400
            row = {
                'soil_type': data.get('soil_type'),
                'flood_frequency': float(data.get('flood_frequency')),
                'rainfall_intensity': float(data.get('rainfall_intensity')),
                'elevation_category': data.get('elevation_category'),
                'distance_from_river': float(data.get('distance_from_river', 0.0)),
            }
            meta = {'sources': {'manual_input': True}}

        import pandas as pd
        X = pd.DataFrame([row])

        _ensure_model_loaded()
        if model is None:
            return jsonify({'error': 'Model not loaded. Train and save a model with model/train_model.py'}), 500

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
                dt_info = {'prediction': dt_pred, 'confidence': dt_conf}
                agree = (str(dt_pred).lower() == str(pred).lower())
            except Exception:
                dt_info = None

        # Post-process to avoid implausible HIGH calls: simple, explainable rules
        def _postprocess(pred, confidence, row):
            # If very low rainfall and high elevation, reduce high -> medium unless extremely confident
            try:
                rain = float(row.get('rainfall_intensity', 0.0))
                elev = row.get('elevation_category')
                flood = float(row.get('flood_frequency', 0.0))
                dist = float(row.get('distance_from_river', 999.0))

                if str(pred).lower() == 'high' and rain < 20.0 and elev == 'high' and confidence < 0.95:
                    return 'Medium', min(confidence + 0.05, 0.95), 'Adjusted from High to Medium because of low recent rainfall and high elevation.'

                # Promote to High when multiple risk factors co-occur: heavy rainfall, frequent flooding, close to river
                if str(pred).lower() != 'high':
                    if rain >= 120.0 and flood >= 3.0 and dist <= 1.5:
                        # increase confidence a bit but keep within bounds
                        return 'High', min(max(confidence, 0.6) + 0.05, 0.99), 'Upgraded to High due to heavy rain, frequent flooding and proximity to river.'
            except Exception:
                pass
            return pred, confidence, None

        adj_pred, adj_conf, adj_note = _postprocess(pred, confidence, row)

        explanation = _simple_explanation(row, importances)
        if meta.get('region'):
            explanation += f" Region: {meta.get('region')}"
        if adj_note:
            explanation += ' ' + adj_note

        recommendation = _recommendation_for_risk(adj_pred)

        fi_list = sorted([(k, float(v)) for k, v in importances.items()], key=lambda x: x[1], reverse=True)

        resp = {
            'risk_level': adj_pred,
            'confidence': float(adj_conf),
            'probabilities': probs,
            'explanation': explanation,
            'recommendation': recommendation,
            'feature_importances': [{'feature': f, 'importance': imp} for f, imp in fi_list],
            'influencing_factors': explanation.split('. '),
            'disclaimer': 'Predictions are indicative and based on available environmental data.'
        }

        # Add meta info and location if available
        if 'region' in meta:
            resp['region'] = meta['region']
        if lat is not None and lon is not None:
            resp['location'] = {'latitude': lat, 'longitude': lon}
            resp['inferred_features'] = {**row, 'meta_sources': meta.get('sources', {})}

        if dt_info is not None:
            resp['model_comparison'] = {'decision_tree': dt_info, 'agree': agree}

        return jsonify(resp), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': 'Server error', 'details': str(e)}), 500


# Old manual-input predict handler removed; the new unified '/api/v1/predict' above handles both location-based and manual inputs.


# Backwards compatible route
@app.route("/predict", methods=["POST"])
def predict():
    # Simple wrapper for compatibility; call new v1 endpoint behavior
    return predict_v1()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
