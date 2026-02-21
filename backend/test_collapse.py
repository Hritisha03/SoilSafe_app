#!/usr/bin/env python
"""Test the _collapse_feature_importances function."""
import sys
sys.path.insert(0, '.')
import joblib
import pandas as pd
import numpy as np
from app import _collapse_feature_importances

# Simulate collapsed importances from built-in
transformed_imps = {
    'cat__soil_type_clay': 0.0010,
    'cat__soil_type_loam': 0.1115,
    'cat__soil_type_sandy': 0.0608,
    'cat__soil_type_silt': 0.0029,
    'cat__elevation_category_high': 0.0759,
    'cat__elevation_category_low': 0.1840,
    'cat__elevation_category_mid': 0.1178,
    'num__flood_frequency': 0.0892,
    'num__rainfall_intensity': 0.1813,
    'num__distance_from_river': 0.1755
}

print('Transformed importances:')
for k, v in transformed_imps.items():
    print(f'  {k}: {v:.4f}')

collapsed = _collapse_feature_importances(transformed_imps)
print('\nCollapsed importances:')
for k, v in sorted(collapsed.items(), key=lambda x: x[1], reverse=True):
    print(f'  {k}: {v:.4f}')
