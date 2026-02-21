#!/usr/bin/env python
"""Test feature importances across multiple diverse input scenarios."""
import json
import requests
import pandas as pd

test_cases = [
    # Low rain, far from river
    {'soil_type': 'sandy', 'flood_frequency': 1.0, 'rainfall_intensity': 0.5, 'elevation_category': 'high', 'distance_from_river': 5.0},
    # High rain, low elevation, close to river
    {'soil_type': 'clay', 'flood_frequency': 5.0, 'rainfall_intensity': 150.0, 'elevation_category': 'low', 'distance_from_river': 0.5},
    # Medium rain, medium elevation, medium distance
    {'soil_type': 'loam', 'flood_frequency': 2.5, 'rainfall_intensity': 50.0, 'elevation_category': 'mid', 'distance_from_river': 2.0},
    # High elevation, very low rainfall
    {'soil_type': 'silt', 'flood_frequency': 0.5, 'rainfall_intensity': 5.0, 'elevation_category': 'high', 'distance_from_river': 10.0},
    # High flood risk
    {'soil_type': 'clay', 'flood_frequency': 8.0, 'rainfall_intensity': 200.0, 'elevation_category': 'low', 'distance_from_river': 0.1},
]

for i, data in enumerate(test_cases):
    print(f"\n--- Test Case {i+1} ---")
    print(f"Input: soil={data['soil_type']}, rain={data['rainfall_intensity']}mm, flood_freq={data['flood_frequency']}, elev={data['elevation_category']}, dist={data['distance_from_river']}km")
    
    try:
        resp = requests.post('http://localhost:5000/predict', json=data, timeout=5)
        result = resp.json()
        
        print(f"Prediction: {result.get('risk_level')} (confidence {result.get('confidence'):.3f})")
        
        # Extract feature importances
        feature_imps = {}
        for fi in result.get('feature_importances', []):
            feat = fi['feature']
            imp = fi['importance']
            if imp > 0.001:  # Only show significant importances
                feature_imps[feat] = imp
        
        if feature_imps:
            print("Feature importances (top 5):")
            sorted_imps = sorted(feature_imps.items(), key=lambda x: x[1], reverse=True)[:5]
            for feat, imp in sorted_imps:
                print(f"  {feat}: {imp:.3f}")
        else:
            print("No feature importances returned")
    except Exception as e:
        print(f"Error: {e}")
