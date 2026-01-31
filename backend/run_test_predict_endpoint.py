import json
import app
import app as appmod

# Replace network-dependent functions

def fake_fetch_rainfall(lat, lon):
    return (0.5, 'fake')

def fake_fetch_elevation(lat, lon):
    return (400.0, 'fake')

appmod._fetch_recent_rainfall_mm = fake_fetch_rainfall
appmod._fetch_elevation_m = fake_fetch_elevation

client = app.app.test_client()
payload = {'latitude': 30.0, 'longitude': 78.0}
resp = client.post('/api/v1/predict', data=json.dumps(payload), content_type='application/json')
print('Status:', resp.status_code)
print(resp.get_json())
