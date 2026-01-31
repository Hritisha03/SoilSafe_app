import json
import app as appmod

# Mock heavy rainfall + low elevation + close to river

def fake_fetch_rainfall(lat, lon):
    return (200.0, 'fake')

def fake_fetch_elevation(lat, lon):
    return (10.0, 'fake')

# Inject mocks
appmod._fetch_recent_rainfall_mm = fake_fetch_rainfall
appmod._fetch_elevation_m = fake_fetch_elevation

# Also mock a region rule with close river distance and high flood frequency
rule = {
    'name': 'Test Floodplain',
    'min_lat': 0,
    'max_lat': 90,
    'min_lon': -180,
    'max_lon': 180,
    'flood_frequency': 5,
    'soil_type': 'clay',
    'distance_from_river': 0.3,
    'rainfall_intensity': 200,
    'elevation_category': 'low'
}
appmod.REGION_RULES.insert(0, rule)

client = appmod.app.test_client()
payload = {'latitude': 20.0, 'longitude': 80.0}
resp = client.post('/api/v1/predict', data=json.dumps(payload), content_type='application/json')
print('Status:', resp.status_code)
print(resp.get_json())
