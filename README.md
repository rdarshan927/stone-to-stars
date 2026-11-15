# Stone to Stars

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Solo submission for NASA Space Apps Challenge 2026 — **"Be An Earth System Trend Detective!"**

Stone to Stars will explore Earth science trends using NASA POWER data. This repo is currently a bare scratch project: no data integration or analysis yet.

## Try Stone to Stars

🌍 **Web Application:** https://senku-stone-to-star.netlify.app

📱 **Android Application:** [Download APK](https://github.com/rdarshan927/stone-to-stars/releases/latest)

💻 **Source Code:** https://github.com/rdarshan927/stone-to-stars

The Android application requires Android installation from an external source. Download the APK from GitHub Releases and install it on your device.

**Note:** The APK is distributed directly through GitHub, not through Google Play.

## Structure

| Path | Purpose |
|------|---------|
| `apps/mobile` | Flutter app (Android + Web) |
| `backend/app` | FastAPI backend |
| `docs` | Project documentation |

## Run the backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Endpoints: `http://127.0.0.1:8000/` and `http://127.0.0.1:8000/health` (docs at `/docs`).

## Run the Flutter app

Requires the Flutter SDK (3.47+).

```bash
cd apps/mobile
flutter pub get
flutter run -d chrome        # Web
flutter run                  # Android device/emulator
flutter build web            # Production web build
```

## License

Copyright 2026 Team SENKU. The original project code is licensed under the
[Apache License 2.0](LICENSE).

Third-party dependencies, logos, datasets, and externally supplied artwork are
not relicensed by this notice and remain subject to their respective rights and
terms. See the [artwork provenance](apps/mobile/assets/observatory/README.md) and
[map provider attribution](apps/mobile/docs/map_setup.md) for existing asset and
data-source notes.
