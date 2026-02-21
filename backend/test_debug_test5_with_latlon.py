#!/usr/bin/env python
"""Test Test 5 with explicit lat/lon."""
import json
import requests

data = {
    'soil_type': 'clay',
    'flood_frequency': 8.0,
    'rainfall_intensity': 200.0,
    'elevation_category': 'low',
    'distance_from_river': 0.1,
    'latitude': 19.5,
    'longitude': 85.0
}

resp = requests.post('http://localhost:5000/api/v1/predict', json=data)
result = resp.json()

print('Feature importances from response:')
for fi in result.get('feature_importances', []):
    print(f"  {fi['feature']}: {fi['importance']:.4f}")

print('\nTotal importance sum:', sum(fi['importance'] for fi in result.get('feature_importances', [])))
