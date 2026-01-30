SoilSafe — Frontend (Flutter)

Overview

A minimal Flutter app skeleton that communicates with the Flask backend to submit soil data and show risk predictions.

Quick start

1. Install Flutter SDK and ensure `flutter` is on PATH.
2. From `frontend/` run:

```bash
flutter pub get
flutter run
```

Configuration

- The app auto-selects a sensible default base URL for the backend:
  - Web: `http://127.0.0.1:5000`
  - Android emulator: `http://10.0.2.2:5000`

- Override at build/run time using a Dart define (recommended) e.g.:

```bash
# Android emulator (explicit)
flutter run --dart-define=API_BASE=http://10.0.2.2:5000

# Web or desktop (explicit)
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:5000
```

- If using a physical device, set `API_BASE` to your machine IP (e.g., `http://192.168.1.100:5000`) and ensure firewall/port 5000 is open.

Location permissions

- The app can auto-detect the user's location and track it (if the user enables tracking). For this to work:
  - Android: add location permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

  - iOS: add keys to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>SoilSafe uses your location to suggest the closest flood region for the assessment.</string>
```

- India-only flood regions

  - This app enforces India-only flood-region data. When location tracking detects coordinates outside India the app will warn and stop tracking.
  - Use the `Flood region (India)` dropdown in the form to select a curated flood-oriented region (e.g., 'Ganges-Brahmaputra Delta', 'Odisha Coast & Mahanadi', 'Kerala (Monsoon-prone)').
  - If your device location is inside India the app will attempt to auto-detect and select the nearest flood region using reverse-geocoding.

- After editing `pubspec.yaml`, run:

```bash
flutter pub get
```

- If you need to run on a physical device ensure `API_BASE` points to your machine IP and port 5000 is reachable.

Notes

- This project is scaffolded for demos/academic use. Expand UI and validation as needed.