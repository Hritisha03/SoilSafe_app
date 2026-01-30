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
- POST /predict -> Accepts JSON with fields:
  - soil_type ("clay"|"silt"|"sand"|"loam")
  - flood_frequency (int)
  - rainfall_intensity (float)
  - elevation_category ("low"|"mid"|"high")
  - distance_from_river (float, optional)

Returns JSON: {"risk":"High|Medium|Low","probabilities":{...},"explanation":"..."}

Notes

- The model is saved using joblib/pickle and loaded at startup.
- Use the provided `data/dataset.csv` as example training data.
