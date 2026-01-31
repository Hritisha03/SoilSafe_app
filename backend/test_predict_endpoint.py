import json
from backend import app
import backend.app as appmod

# Monkeypatch helper functions to avoid real network calls

def test_predict_low_rain_high_elevation(monkeypatch):
    # Mock rainfall to be very low
    def fake_fetch_rainfall(lat, lon):
        return (0.5, 'fake')

    # Mock elevation high
    def fake_fetch_elevation(lat, lon):
        return (400.0, 'fake')

    monkeypatch.setattr(appmod, '_fetch_recent_rainfall_mm', fake_fetch_rainfall)
    monkeypatch.setattr(appmod, '_fetch_elevation_m', fake_fetch_elevation)

    client = app.test_client()
    payload = {'latitude': 30.0, 'longitude': 78.0}
    resp = client.post('/api/v1/predict', data=json.dumps(payload), content_type='application/json')
    assert resp.status_code == 200
    j = resp.get_json()
    assert 'risk_level' in j
    assert j['confidence'] is not None
    # With very low rainfall and high elevation, expect not-high risk unless model says so
    assert j['risk_level'] in ('Low', 'Medium', 'low', 'medium', 'LOW', 'MEDIUM')


if __name__ == '__main__':
    test_predict_low_rain_high_elevation(print)
    print('OK')
