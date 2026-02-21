from flask import Flask, request, jsonify
import joblib
import os
import traceback
import requests
from datetime import datetime, timedelta
import numpy as np
import pandas as pd

try:
    import shap
    SHAP_AVAILABLE = True
except ImportError:
    SHAP_AVAILABLE = False
    shap = None
try:
    from flask_cors import CORS
except ImportError:
    def CORS(app):
        pass

def _collapse_feature_importances(feature_importances_transformed):
    """
    Collapse transformed feature importances (with names like 'cat__soil_type_clay')
    back to original feature names (like 'soil_type', 'rainfall_intensity', etc.)
    by summing contributions from each original feature.
    """
    # Mapping from common patterns to original feature names
    feature_mapping = {
        'soil_type': 'soil_type',
        'elevation_category': 'elevation_category',
        'flood_frequency': 'flood_frequency',
        'rainfall_intensity': 'rainfall_intensity',
        'distance_from_river': 'distance_from_river',
        'rainfall': 'rainfall_intensity',  # Common abbreviation
        'flood': 'flood_frequency',
        'elevation': 'elevation_category',
        'distance': 'distance_from_river',
    }
    
    collapsed = {}
    for feat_name, imp in feature_importances_transformed.items():
        # Extract original feature name from transformed name
        # Format: 'cat__feature_name_value' or 'num__feature_name'
        if '__' in feat_name:
            parts = feat_name.split('__')
            original_feat = parts[1]
            # Remove the value suffix for categorical features (e.g., 'soil_type_clay' -> 'soil_type')
            if parts[0] == 'cat' and '_' in original_feat:
                # For categoricals, keep only the feature name (before the last underscore)
                original_feat = '_'.join(original_feat.split('_')[:-1])
        else:
            original_feat = feat_name
        
        # Map to canonical name
        canonical_feat = feature_mapping.get(original_feat, original_feat)
        
        # Sum contributions from all one-hot encoded versions of same feature
        collapsed[canonical_feat] = collapsed.get(canonical_feat, 0.0) + imp
    
    # Normalize
    total = sum(collapsed.values()) or 1.0
    return {k: v / total for k, v in collapsed.items()}



def _compute_feature_importance_permutation(clf, X_transformed, feature_names):
    """
    Improved permutation-based feature importance that better reflects feature contribution.
    Permutes each feature and measures change in prediction confidence/uncertainty.
    Works on already-transformed feature space (X_transformed).
    """
    try:
        base_pred = clf.predict(X_transformed)[0]
        base_proba = clf.predict_proba(X_transformed)[0]
        base_confidence = np.max(base_proba)
        base_entropy = -np.sum(base_proba * np.log(base_proba + 1e-10))  # Add small epsilon to avoid log(0)
        
        importances = {}
        for i, col in enumerate(feature_names):
            X_perm = X_transformed.copy()
            # Permute this feature column (shuffle values)
            if isinstance(X_perm, pd.DataFrame):
                X_perm.iloc[:, i] = np.random.permutation(X_perm.iloc[:, i].values)
            else:
                X_perm[:, i] = np.random.permutation(X_perm[:, i])
            
            perm_pred = clf.predict(X_perm)[0]
            perm_proba = clf.predict_proba(X_perm)[0]
            perm_confidence = np.max(perm_proba)
            perm_entropy = -np.sum(perm_proba * np.log(perm_proba + 1e-10))
            
            # Importance = how much prediction changes when this feature is shuffled
            pred_change = 1.0 if perm_pred != base_pred else 0.0
            conf_change = abs(base_confidence - perm_confidence)
            entropy_change = abs(base_entropy - perm_entropy)
            
            # Weight: prediction change (70%), confidence change (15%), entropy change (15%)
            importances[col] = float(pred_change * 0.7 + conf_change * 0.15 + entropy_change * 0.15)
        
        # Normalize
        total = sum(importances.values()) or 1.0
        importances = {k: v / total for k, v in importances.items()}
        
        return importances
    except Exception as e:
        app.logger.debug(f"Permutation importance failed: {e}")
        return {}


def _local_feature_importance(pipeline, X_raw):
    """
    Compute per-prediction feature importance for a scikit-learn pipeline.
    Handles extracting preprocessor, transforming X, computing importance on transformed space.
    Returns a simplified dict with original feature names.
    """
    try:
        # Extract pipeline components
        pre = pipeline.named_steps.get('pre')
        clf = pipeline.named_steps.get('clf')
        
        if pre is None or clf is None:
            app.logger.debug("Pipeline missing 'pre' or 'clf' step")
            return {}
        
        # Transform the raw input using the preprocessor
        X_transformed = pre.transform(X_raw)
        
        # Get feature names after transformation
        if hasattr(pre, 'get_feature_names_out'):
            feature_names_transformed = list(pre.get_feature_names_out())
        else:
            # Fallback: use numeric indices as feature names
            feature_names_transformed = [f"feature_{i}" for i in range(X_transformed.shape[1])]
        
        # Try SHAP first (more interpretable for tree models)
        if SHAP_AVAILABLE and X_transformed.shape[0] == 1:
            try:
                explainer = shap.TreeExplainer(clf)
                shap_values = explainer.shap_values(X_transformed)
                
                # For multi-class, shap_values is list of arrays
                pred = clf.predict(X_transformed)[0]
                pred_class_idx = list(clf.classes_).index(pred)
                sv = shap_values[pred_class_idx][0] if isinstance(shap_values, list) else shap_values[0]
                
                # Aggregate SHAP values by feature
                importances = {}
                for i, name in enumerate(feature_names_transformed):
                    importances[name] = float(np.abs(sv[i]))
                
                # Normalize
                total = sum(importances.values()) or 1.0
                importances = {k: v / total for k, v in importances.items()}
                app.logger.info("Using SHAP-based feature importance")
                return _collapse_feature_importances(importances)
            except Exception as e:
                app.logger.debug(f"SHAP failed ({e}), using permutation importance")
        
        # Fallback: improved permutation importance on transformed data
        perm_imps = _compute_feature_importance_permutation(clf, X_transformed, feature_names_transformed)
        perm_total = sum(perm_imps.values()) if perm_imps else 0
        
        # If permutation importance is meaningful (non-zero sum), use it
        if perm_imps and perm_total > 1e-6:
            app.logger.info(f"Using permutation importance")
            return _collapse_feature_importances(perm_imps)
        
        # Last fallback: model's built-in feature importances (if available)
        # Use this when permutation doesn't yield insights (e.g., supremely confident predictions)
        try:
            if hasattr(clf, 'feature_importances_'):
                importances = {name: float(imp) for name, imp in zip(feature_names_transformed, clf.feature_importances_)}
                total = sum(importances.values()) or 1.0
                importances = {k: v / total for k, v in importances.items()}
                app.logger.info("Using model's built-in feature importances (permutation was near-zero)")
                return _collapse_feature_importances(importances)
        except Exception as e:
            app.logger.debug(f"Built-in importances failed: {e}")
        
        return {}
    
    except Exception as e:
        app.logger.error(f"Feature importance computation failed: {e}, traceback: {traceback.format_exc()}")
        return {}

_default_model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "model/soil_model.pkl"))
_env_model = os.environ.get("SOIL_MODEL_PATH")
if os.path.exists(_default_model_path):
    MODEL_PATH = _default_model_path
elif _env_model:
    
    cand1 = os.path.abspath(_env_model)
    cand2 = os.path.abspath(os.path.join(os.path.dirname(__file__), _env_model))
    if os.path.exists(cand1):
        MODEL_PATH = cand1
    elif os.path.exists(cand2):
        MODEL_PATH = cand2
    else:
        
        MODEL_PATH = cand1
else:
    MODEL_PATH = _default_model_path

app = Flask(__name__)
# Enable CORS for all routes - critical for Flutter web frontend
CORS(app)


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
            "High risk: Early inspection and monitoring is recommended before land reuse or heavy activity. This supports disaster response planning and risk mitigation."
        )
    if risk_level.lower() == 'medium':
        return (
            "Moderate risk: Periodic monitoring is advised. While no immediate intervention is required, localized assessment may be needed if environmental conditions change."
        )
    return (
        "Low risk: No immediate action is required under current conditions. Routine observation and standard land use practices are considered sufficient."
    )


def _compute_region_adjusted_importances(base_importances, row, region_rule, lat, lon):
    """Compute region-specific feature importances based on how inferred features
    deviate from regional norms and influence risk."""
    adj = dict(base_importances)
    if not region_rule:
        return adj
    try:
        rainfall = float(row.get('rainfall_intensity', 0.0))
        rain_norm = float(region_rule.get('rainfall_intensity', 50.0))
        flood = float(row.get('flood_frequency', 1.0))
        flood_norm = float(region_rule.get('flood_frequency', 1.0))
        dist = float(row.get('distance_from_river', 2.0))
        dist_norm = float(region_rule.get('distance_from_river', 2.0))
        elev_cat = row.get('elevation_category', 'mid')
        elev_norm = region_rule.get('elevation_category', 'mid')
        soil = row.get('soil_type', 'silt')
        soil_norm = region_rule.get('soil_type', 'silt')
        rainfall_ratio = rainfall / max(rain_norm, 1.0)
        flood_ratio = flood / max(flood_norm, 1.0)
        dist_ratio = dist / max(dist_norm, 0.1)
        if rainfall_ratio > 1.5 or rainfall_ratio < 0.5:
            adj['rainfall_intensity'] = min(adj.get('rainfall_intensity', 0.2) * 1.4, 0.4)
        if flood_ratio > 1.5:
            adj['flood_frequency'] = min(adj.get('flood_frequency', 0.15) * 1.3, 0.35)
        elif flood_ratio > 0.8:
            adj['flood_frequency'] = max(adj.get('flood_frequency', 0.15) * 0.8, 0.05)
        if dist < 1.0:
            adj['distance_from_river'] = min(adj.get('distance_from_river', 0.18) * 1.5, 0.40)
        elif dist_ratio < 0.3:
            adj['distance_from_river'] = min(adj.get('distance_from_river', 0.18) * 1.2, 0.35)
        if elev_cat != elev_norm:
            adj['elevation_category'] = min(adj.get('elevation_category', 0.16) * 1.3, 0.35)
        if soil != soil_norm:
            adj['soil_type'] = min(adj.get('soil_type', 0.25) * 1.2, 0.40)
        total = sum(adj.values())
        if total > 0:
            adj = {k: v / total for k, v in adj.items()}
    except Exception:
        pass
    return adj





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

   
    rule = _lookup_region_rule(lat, lon)

    
    rainfall_mm, rainfall_src = _fetch_recent_rainfall_mm(lat, lon)
    meta['sources']['rainfall'] = rainfall_src

    
    if rainfall_mm is not None:
        rainfall_intensity = float(rainfall_mm)
    else:
        rainfall_intensity = None

  
    rainfall_category = _rainfall_category_from_mm(rainfall_intensity)
    if rainfall_category is not None:
        meta['rainfall_category'] = rainfall_category

    #
    elev_m, elev_src = _fetch_elevation_m(lat, lon)
    meta['sources']['elevation'] = elev_src
    elev_cat = _elevation_category_from_m(elev_m)

    
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
        'rainfall_category': rainfall_category,
    }

   
    if elev_m is not None:
        meta['elevation_m'] = float(elev_m)

    return features, meta


@app.route('/api/v1/predict-location', methods=['POST'])
def predict_by_location():
    """Legacy compatibility endpoint: accepts JSON { latitude, longitude, region (optional) } and returns structured response.
    Delegates to the unified predict endpoint behavior but keeps the older path for existing clients."""
    data = request.get_json(force=True)

    lat = data.get('latitude')
    lon = data.get('longitude')
    if lat is None or lon is None:
        return jsonify({'error': 'Missing latitude or longitude'}), 400
    
    return predict_v1()



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

      
        if isinstance(model, dict):
            rf = model.get('rf')
            dt = model.get('dt')
        else:
            rf = model
            dt = None
        
        # Compute feature importances for this specific prediction
        importances = _local_feature_importance(rf, X) if hasattr(rf, 'named_steps') else {}


        
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
                dt_info = {'prediction': dt_pred, 'confidence': dt_conf}
                agree = (str(dt_pred).lower() == str(pred).lower())
            except Exception:
                dt_info = None

       
        def _postprocess(pred, confidence, row):
          
            try:
                rain = float(row.get('rainfall_intensity', 0.0))
                elev = row.get('elevation_category')
                flood = float(row.get('flood_frequency', 0.0))
                dist = float(row.get('distance_from_river', 999.0))

                if str(pred).lower() == 'high' and rain < 20.0 and elev == 'high' and confidence < 0.95:
                    return 'Medium', min(confidence + 0.05, 0.95), 'Adjusted from High to Medium because of low recent rainfall and high elevation.'

                
                if str(pred).lower() != 'high':
                    if rain >= 120.0 and flood >= 3.0 and dist <= 1.5:
                        
                        return 'High', min(max(confidence, 0.6) + 0.05, 0.99), 'Upgraded to High due to heavy rain, frequent flooding and proximity to river.'
            except Exception:
                pass
            return pred, confidence, None

        adj_pred, adj_conf, adj_note = _postprocess(pred, confidence, row)

        # Compute region-adjusted importances instead of global static importances
        base_importances = importances if importances else {}
        rule = _lookup_region_rule(lat, lon) if lat is not None and lon is not None else None
        importances = _compute_region_adjusted_importances(base_importances, row, rule, lat, lon)

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



@app.route("/predict", methods=["POST"])
def predict():
  
    return predict_v1()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
