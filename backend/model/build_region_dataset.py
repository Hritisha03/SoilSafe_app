"""Build a region-level dataset for Eastern India using region rules and public APIs.

This script samples locations within region bounding boxes defined in
`data/region_rules.json`, fetches recent rainfall and elevation when available,
and derives labels using an expert-inspired rule-based rubric.

Output: CSV at backend/data/region_dataset.csv by default.
"""
import os
import json
import random
import time
from typing import Tuple
import requests
import pandas as pd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RULES_PATH = os.path.join(ROOT, 'data', 'region_rules.json')
OUT_PATH = os.path.join(ROOT, 'data', 'region_dataset.csv')

# Config
SAMPLES_PER_REGION = 200  # keeps dataset modest for demo
RNG = random.Random(42)


def parse_args():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--samples-per-region', type=int, default=SAMPLES_PER_REGION,
                    help='Number of points to sample per region (default: 200)')
    ap.add_argument('--out', type=str, default=OUT_PATH, help='Output CSV path')
    ap.add_argument('--offline', action='store_true', help='Use region-rule defaults; do not call external APIs')
    return ap.parse_args()


def _fetch_rainfall_24h(lat: float, lon: float) -> Tuple[float, str]:
    try:
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=precipitation&past_days=1&timezone=UTC"
        r = requests.get(url, timeout=8)
        r.raise_for_status()
        j = r.json()
        hourly = j.get('hourly', {})
        precip = hourly.get('precipitation', [])
        if precip:
            total = float(sum(precip))
            return total, 'open-meteo'
    except Exception:
        pass
    return None, 'fallback'


def _fetch_elevation(lat: float, lon: float) -> Tuple[float, str]:
    try:
        url = f"https://api.open-elevation.com/api/v1/lookup?locations={lat},{lon}"
        r = requests.get(url, timeout=6)
        r.raise_for_status()
        j = r.json()
        results = j.get('results') or []
        if results and results[0].get('elevation') is not None:
            return float(results[0]['elevation']), 'open-elevation'
    except Exception:
        pass
    return None, 'fallback'


def label_from_features(soil_type, flood_freq, rainfall_mm, elev_cat, dist_km):
    """Derive a label using clear, explainable rules."""
    score = 0
    # soil
    if soil_type in ('clay', 'silt'):
        score += 1
    # flood
    if flood_freq >= 4:
        score += 2
    elif flood_freq >= 2:
        score += 1
    # rainfall (24h)
    if rainfall_mm is not None:
        if rainfall_mm >= 150:
            score += 2
        elif rainfall_mm >= 50:
            score += 1
    # elevation
    if elev_cat == 'low':
        score += 1
    # distance
    if dist_km is not None and dist_km < 1.0:
        score += 1

    # Adjust: high elevation and low rainfall should reduce score
    if elev_cat == 'high' and (rainfall_mm is None or rainfall_mm < 20):
        score = max(0, score - 1)

    if score >= 4:
        return 'High'
    if score >= 2:
        return 'Medium'
    return 'Low'


def sample_point_within(region):
    lat = RNG.uniform(float(region['min_lat']), float(region['max_lat']))
    lon = RNG.uniform(float(region['min_lon']), float(region['max_lon']))
    return lat, lon


def build_dataset(out_path=OUT_PATH, use_offline=False):
    with open(RULES_PATH, 'r', encoding='utf8') as fh:
        rules = json.load(fh)

    rows = []
    for r in rules:
        name = r.get('name')
        for _ in range(SAMPLES_PER_REGION):
            lat, lon = sample_point_within(r)
            if use_offline:
                # Use rule-provided nominal values when offline to avoid external API calls
                rainfall = r.get('rainfall_intensity')
                rsrc = 'region-rule-offline' if r.get('rainfall_intensity') is not None else 'default'
                elev_m = None
                esrc = 'region-rule-offline' if r.get('elevation_category') is not None else 'default'
                elev_cat = r.get('elevation_category') if r.get('elevation_category') else 'mid'
            else:
                rainfall, rsrc = _fetch_rainfall_24h(lat, lon)
                elev_m, esrc = _fetch_elevation(lat, lon)
                elev_cat = r.get('elevation_category') if r.get('elevation_category') else ('mid')
                # prefer fetched elevation to override category
                if elev_m is not None:
                    if elev_m < 50:
                        elev_cat = 'low'
                    elif elev_m < 300:
                        elev_cat = 'mid'
                    else:
                        elev_cat = 'high'

            flood_freq = float(r.get('flood_frequency', 1.0))
            soil_type = r.get('soil_type', 'silt')
            dist = float(r.get('distance_from_river', 2.0))

            label = label_from_features(soil_type, flood_freq, rainfall, elev_cat, dist)

            rows.append({
                'region': name,
                'latitude': lat,
                'longitude': lon,
                'soil_type': soil_type,
                'flood_frequency': flood_freq,
                'rainfall_intensity': (float(rainfall) if rainfall is not None else None),
                'elevation_category': elev_cat,
                'distance_from_river': dist,
                'label': label,
                'rainfall_source': rsrc,
                'elevation_source': esrc,
            })
            # be gentle with public APIs
            if not use_offline:
                time.sleep(0.05)

    df = pd.DataFrame(rows)

    # Fix missing rainfall by filling with regional nominal
    df['rainfall_intensity'] = df.groupby('region')['rainfall_intensity'].transform(
        lambda x: x.fillna(x.mean() if not pd.isna(x.mean()) else 50)
    )

    # Derive categorical rainfall bucket for explanation / training
    def _rainfall_category_from_mm(mm):
        try:
            mm = float(mm)
            if mm < 20.0:
                return 'Light'
            if mm <= 100.0:
                return 'Moderate'
            return 'Heavy'
        except Exception:
            return None

    df['rainfall_category'] = df['rainfall_intensity'].apply(_rainfall_category_from_mm)

    # Balance classes by upsampling minority classes
    counts = df['label'].value_counts()
    print('Class counts before balancing:', counts.to_dict())
    maxc = counts.max()
    dfs = [df[df['label'] == lbl] for lbl in counts.index]
    balanced = pd.concat([d.sample(maxc, replace=True, random_state=42) for d in dfs])
    balanced = balanced.sample(frac=1, random_state=42).reset_index(drop=True)
    print('Class counts after balancing:', balanced['label'].value_counts().to_dict())

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    balanced.to_csv(out_path, index=False)
    print('Saved region dataset to', out_path)
    return balanced


if __name__ == '__main__':
    args = parse_args()
    SAMPLES_PER_REGION = args.samples_per_region
    df = build_dataset(out_path=args.out, use_offline=args.offline)
    print(df.head())
