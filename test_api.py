#!/usr/bin/env python
"""Quick integration test of the backend API."""
import requests
import json

url = 'http://127.0.0.1:5000/api/v1/predict'
payload = {
    'soil_type': 'clay',
    'flood_frequency': 3,
    'rainfall_intensity': 100,
    'elevation_category': 'low',
    'distance_from_river': 0.8,
    'region': 'West Bengal Coast'
}

try:
    resp = requests.post(url, json=payload, timeout=5)
    print(f"Status: {resp.status_code}")
    result = resp.json()
    print("Response:")
    print(json.dumps(result, indent=2))
    
    # Check key fields
    assert 'risk_level' in result, "Missing risk_level"
    assert 'confidence' in result, "Missing confidence"
    assert 'explanation' in result, "Missing explanation"
    assert 'recommendation' in result, "Missing recommendation"
    assert 'feature_importances' in result, "Missing feature_importances"
    print("\n✓ All required fields present!")
    
except Exception as e:
    print(f"Error: {e}")
