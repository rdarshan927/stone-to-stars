# Stone to Stars

Solo submission for NASA Space Apps Challenge 2026 — **"Be An Earth System Trend Detective!"**

Stone to Stars will explore Earth science trends using NASA POWER data. This repo is currently a bare scratch project: no data integration or analysis yet.

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
