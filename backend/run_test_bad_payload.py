import json
import app as appmod

client = appmod.app.test_client()
# send empty JSON
resp = client.post('/api/v1/predict', data=json.dumps({}), content_type='application/json')
print('Status:', resp.status_code)
print(resp.get_data(as_text=True))
