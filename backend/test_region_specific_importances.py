"""Test that feature importances vary by region"""
import json
import app as appmod

# Mock callbacks
def mock_rainfall_low(lat, lon):
    return (5.0, 'fake')

def mock_rainfall_high(lat, lon):
    return (200.0, 'fake')

def mock_elev_high(lat, lon):
    return (600.0, 'fake')

def mock_elev_low(lat, lon):
    return (20.0, 'fake')

# Test 1: High-elevation region with low rainfall
print("=" * 60)
print("Test 1: High elevation, low rainfall (hill region)")
print("=" * 60)
appmod._fetch_recent_rainfall_mm = mock_rainfall_low
appmod._fetch_elevation_m = mock_elev_high

client = appmod.app.test_client()
payload = {'latitude': 32.0, 'longitude': 77.0}  # Himalayan region
resp1 = client.post('/api/v1/predict', data=json.dumps(payload), content_type='application/json')
data1 = resp1.get_json()
importances1 = {f['feature']: f['importance'] for f in data1.get('feature_importances', [])}
print(f"Risk: {data1.get('risk_level')}")
print(f"Importances: {importances1}")

# Test 2: Low-elevation region with heavy rainfall
print("\n" + "=" * 60)
print("Test 2: Low elevation, heavy rainfall (floodplain region)")
print("=" * 60)
appmod._fetch_recent_rainfall_mm = mock_rainfall_high
appmod._fetch_elevation_m = mock_elev_low

payload = {'latitude': 22.0, 'longitude': 88.0}  # Coastal/delta region
resp2 = client.post('/api/v1/predict', data=json.dumps(payload), content_type='application/json')
data2 = resp2.get_json()
importances2 = {f['feature']: f['importance'] for f in data2.get('feature_importances', [])}
print(f"Risk: {data2.get('risk_level')}")
print(f"Importances: {importances2}")

# Verify they differ
print("\n" + "=" * 60)
print("Comparison:")
print("=" * 60)
differences = {}
for feat in importances1.keys():
    diff = abs(importances1[feat] - importances2[feat])
    differences[feat] = diff
    print(f"{feat}: Region1={importances1[feat]:.4f}, Region2={importances2[feat]:.4f}, Diff={diff:.4f}")

avg_diff = sum(differences.values()) / len(differences)
print(f"\nAverage importance difference: {avg_diff:.4f}")

if avg_diff > 0.01:  # Expect meaningful differences
    print("\n✓ PASS: Feature importances vary significantly by region")
else:
    print("\n✗ FAIL: Feature importances are too similar across regions")
