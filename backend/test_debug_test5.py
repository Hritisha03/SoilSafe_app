#!/usr/bin/env python
"""Debug Test 5 importances."""
import json
import requests

data = {'soil_type': 'clay', 'flood_frequency': 8.0, 'rainfall_intensity': 200.0, 'elevation_category': 'low', 'distance_from_river': 0.1}
resp = requests.post('http://localhost:5000/predict', json=data)
result = resp.json()

print('Feature importances from response:')
for fi in result.get('feature_importances', []):
    print(f"  {fi['feature']}: {fi['importance']}")

print('\nTotal importances count:', len(result.get('feature_importances', [])))
print('Non-zero importances:', len([fi for fi in result.get('feature_importances', []) if fi['importance'] > 0]))
