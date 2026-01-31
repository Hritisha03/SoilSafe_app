"""Run a quick test of backend endpoints using Flask test client (no server required)."""
import os
import json
from app import app, MODEL_PATH

print('cwd', os.getcwd())
print('MODEL_PATH', MODEL_PATH, 'exists=', os.path.exists(MODEL_PATH))

with app.test_client() as client:
    resp = client.post('/api/v1/predict-location', json={'latitude': 25.6, 'longitude': 85.1})
    print('Status', resp.status_code)
    print(json.dumps(resp.get_json(), indent=2))

    resp2 = client.post('/api/v1/predict', json={
        'soil_type': 'clay', 'flood_frequency': 3, 'rainfall_intensity': 120, 'elevation_category': 'low'
    })
    print('Status', resp2.status_code)
    print(json.dumps(resp2.get_json(), indent=2))