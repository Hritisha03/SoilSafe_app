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

- Edit `lib/services/api_service.dart` to point to your backend base URL (default `http://10.0.2.2:5000` for Android emulator).

Notes

- This project is scaffolded for demos/academic use. Expand UI and validation as needed.