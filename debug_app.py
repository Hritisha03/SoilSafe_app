#!/usr/bin/env python
import sys
sys.path.insert(0, 'backend')
import app as app_module

print("Module attributes containing 'predict':")
for name in dir(app_module):
    if 'predict' in name.lower():
        obj = getattr(app_module, name)
        print(f"  {name}: {type(obj)}")

print(f"\nTotal functions in module: {len([x for x in dir(app_module) if callable(getattr(app_module, x)) and not x.startswith('_')])}")

print(f"\nFlask routes registered:")
for rule in app_module.app.url_map.iter_rules():
    print(f"  {rule}")

# Try searching in module source for the function definition
import inspect
source = inspect.getsource(app_module)
if 'def predict_v1' in source:
    print("\n'def predict_v1' FOUND in source code")
else:
    print("\n'def predict_v1' NOT found in source code")

if '@app.route(\'/api/v1/predict\'' in source:
    print("'@app.route('/api/v1/predict' FOUND in source code")
else:
    print("'@app.route('/api/v1/predict' NOT found in source code")
