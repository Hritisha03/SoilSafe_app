"""Flask API for SoilSafe

Endpoints:
- GET /health
- POST /predict

Expect JSON payload and return risk prediction JSON.
"""
from flask import Flask, request, jsonify
import joblib
import os
import traceback


try:
    from flask_cors import CORS  # type: ignore
except ImportError:
    def CORS(app):  # type: ignore
        pass

MODEL_PATH = os.environ.get("SOIL_MODEL_PATH", "model/soil_model.pkl")

app = Flask(__name__)
CORS(app)

# Load model at startup
model = None
if os.path.exists(MODEL_PATH):
    try:
        model = joblib.load(MODEL_PATH)
        app.logger.info(f"Loaded model from {MODEL_PATH}")
    except Exception as e:
        app.logger.error("Failed to load model: %s", e)
else:
    app.logger.warning("Model file not found. Run `python model/train_model.py` to create it.")


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


def validate_input(d):
    required = ["soil_type", "flood_frequency", "rainfall_intensity", "elevation_category"]
    for k in required:
        if k not in d:
            return False, f"Missing field: {k}"
    # More validation can be added here
    return True, None


@app.route("/predict", methods=["POST"])
def predict():
    global model
    try:
        data = request.get_json(force=True)
        ok, err = validate_input(data)
        if not ok:
            return jsonify({"error": err}), 400

        if model is None:
            return jsonify({"error": "Model not loaded. Train and save a model with model/train_model.py"}), 500

        # Build single-row DataFrame
        import pandas as pd
        # Keep only the features used by the model for prediction. Accept optional location/region for context.
        row = {
            "soil_type": data.get("soil_type"),
            "flood_frequency": float(data.get("flood_frequency")),
            "rainfall_intensity": float(data.get("rainfall_intensity")),
            "elevation_category": data.get("elevation_category"),
            "distance_from_river": float(data.get("distance_from_river", 0.0)),
        }
        X = pd.DataFrame([row])

        pred = model.predict(X)[0]
        probs = None
        try:
            proba = model.predict_proba(X)[0]
            classes = model.classes_
            probs = {c: float(p) for c, p in zip(classes, proba)}
        except Exception:
            probs = None

        lat = data.get("latitude")
        lon = data.get("longitude")
        region = data.get("region")

        explanation = (
            "Soil risk predicted based on flood frequency, rainfall intensity, soil type and elevation."
        )
        if region:
            explanation += f" Region provided: {region}."
        if lat and lon:
            explanation += " Location coordinates were provided and used for context." 

        resp = {"risk": pred, "probabilities": probs, "explanation": explanation}
        if region:
            resp["region"] = region
        if lat and lon:
            try:
                resp["location"] = {"latitude": float(lat), "longitude": float(lon)}
            except Exception:
                resp["location"] = {"raw_lat": lat, "raw_lon": lon}

        return jsonify(resp), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": "Server error", "details": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
