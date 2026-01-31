SoilSafe — Backend (Flask + scikit-learn)

Overview

This folder contains a Flask REST API that loads a scikit-learn model from a Pickle file and exposes a `/predict` endpoint.

Requirements

- Python 3.9+
- Create a virtualenv and install requirements:

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Train model (generates `model/soil_model.pkl`):

```bash
python model/train_model.py --output model/soil_model.pkl
```

Run the API (development):

```bash
set FLASK_APP=app.py
flask run --host=0.0.0.0 --port=5000
```

API

- GET /health -> {"status":"ok"}
- POST /api/v1/predict -> Accepts JSON with fields:
  - soil_type ("clay"|"silt"|"sand"|"loam")
  - flood_frequency (int)
  - rainfall_intensity (float)
  - elevation_category ("low"|"mid"|"high")
  - distance_from_river (float, optional)
  - latitude (float, optional)  # optional: user/device location
  - longitude (float, optional) # optional: user/device location
  - region (string, optional)   # optional: region name provided by user or auto-detected

Returns structured JSON:
{
  "risk_level": "High|Medium|Low",
  "confidence": 0.87,
  "probabilities": {"High":0.87, "Medium":0.10, "Low":0.03},
  "explanation": "Human-readable reasoning",
  "recommendation": "Safety advice based on risk",
  "feature_importances": [{"feature":"flood_frequency","importance":0.45}, ...],
  "influencing_factors": ["Frequent flooding (3) increases ...", ...],
  "model_comparison": {"decision_tree": {"prediction":"High","confidence":0.7}, "agree": true}
}

(An unversioned `/predict` endpoint also exists for backward compatibility and forwards to `/api/v1/predict`.)

- POST /api/v1/predict-location -> Accepts JSON with fields:
  - latitude (float)  -- required
  - longitude (float) -- required
  - region (string)   -- optional human-readable region hint

  The endpoint uses an academic, rule-based regional lookup to infer model features (rainfall_intensity, flood_frequency, elevation_category, soil_type, distance_from_river) from latitude/longitude and returns the same structured JSON as `/api/v1/predict`, plus an `inferred_features` summary and `disclaimer`.

Notes

- The model is saved using joblib/pickle and loaded at startup.
- Use the provided `data/dataset.csv` as example training data.
