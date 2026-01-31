#!/usr/bin/env python
"""Quick integration test for /api/v1/predict-location endpoint."""
import requests
import json

url = 'http://127.0.0.1:5000/api/v1/predict-location'
payload = {
    'latitude': 25.6,
    'longitude': 85.1
}

try:
    resp = requests.post(url, json=payload, timeout=5)
    print(f"Status: {resp.status_code}")
    result = resp.json()
    print("Response:")
    print(json.dumps(result, indent=2))
    
    assert resp.status_code == 200, f"Status {resp.status_code}"
    for k in ('risk_level', 'confidence', 'explanation', 'recommendation', 'inferred_features'):
        assert k in result, f"Missing {k}"

    print("\n✓ /predict-location returned expected keys")

except Exception as e:
    print(f"Error: {e}")