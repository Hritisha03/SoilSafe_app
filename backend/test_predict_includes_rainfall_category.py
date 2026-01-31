import json
import sys
import app as appmod

# Mock low rainfall to get 'Light' category

def fake_fetch_rainfall(lat, lon):
    return (5.0, 'fake')


def fake_fetch_elevation(lat, lon):
    return (120.0, 'fake')

appmod._fetch_recent_rainfall_mm = fake_fetch_rainfall
appmod._fetch_elevation_m = fake_fetch_elevation

client = appmod.app.test_client()
payload = {'latitude': 10.0, 'longitude': 80.0}
resp = client.post('/api/v1/predict', data=json.dumps(payload), content_type='application/json')

if resp.status_code != 200:
    print('FAIL: status', resp.status_code)
    sys.exit(2)

data = resp.get_json()
if 'inferred_features' not in data:
    print('FAIL: missing inferred_features')
    sys.exit(3)

inf = data['inferred_features']
if 'rainfall_category' not in inf:
    print('FAIL: missing rainfall_category in inferred_features')
    sys.exit(4)

if inf['rainfall_category'] != 'Light':
    print('FAIL: expected Light, got', inf['rainfall_category'])
    sys.exit(5)

print('PASS: rainfall_category == Light')
print(data)
sys.exit(0)
