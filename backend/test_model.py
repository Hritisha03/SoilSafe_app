import os
import joblib

MODEL_PATH = os.path.join('model', 'soil_model.pkl')
print('Model path exists:', os.path.exists(MODEL_PATH))

if os.path.exists(MODEL_PATH):
    try:
        model = joblib.load(MODEL_PATH)
        print('Model loaded successfully')
        print('Model type:', type(model))
        print('Model keys:', list(model.keys()) if hasattr(model, 'keys') else 'No keys')
    except Exception as e:
        print('Error loading model:', str(e))
else:
    print('Model file not found')