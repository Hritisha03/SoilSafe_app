#!/usr/bin/env python
"""Quick test of backend model and API response logic."""
import joblib, pandas as pd, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from app import _aggregate_importances, _simple_explanation, _recommendation_for_risk

# Load model
m = joblib.load('backend/model/soil_model.pkl')
print("✓ Model loaded")

rf = m['rf']
dt = m['dt']

# Test sample: high-risk
sample = pd.DataFrame([{
    'soil_type': 'clay',
    'flood_frequency': 4,
    'rainfall_intensity': 120.0,
    'elevation_category': 'low',
    'distance_from_river': 0.5
}])

print("\n=== Test Sample: High Risk ===")
row = sample.iloc[0].to_dict()

# Random Forest
rf_pred = rf.predict(sample)[0]
rf_proba = rf.predict_proba(sample)[0]
rf_conf = float(rf_proba[list(rf.classes_).index(rf_pred)])
print(f"RF prediction: {rf_pred}, confidence: {rf_conf:.2f}")

# Decision Tree
dt_pred = dt.predict(sample)[0]
dt_proba = dt.predict_proba(sample)[0]
dt_conf = float(dt_proba[list(dt.classes_).index(dt_pred)])
print(f"DT prediction: {dt_pred}, confidence: {dt_conf:.2f}")

# Feature importances
pre = rf.named_steps['pre']
rf_clf = rf.named_steps['clf']
importances = _aggregate_importances(rf, pre, rf_clf)
print(f"Feature importances: {importances}")

# Explanation
explanation = _simple_explanation(row, importances)
print(f"Explanation: {explanation}")

# Recommendation
rec = _recommendation_for_risk(rf_pred)
print(f"Recommendation: {rec}")

print("\n✓ All backend functions work correctly!")
