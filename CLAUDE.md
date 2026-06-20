# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Running the App

The easiest way to start everything is the PowerShell launcher at the repo root:

```powershell
.\run.ps1                              # uses smart_fit_backend/.env for keys
.\run.ps1 -GeminiKey "AIza..."         # pass Gemini key directly
.\run.ps1 -Device "windows"            # target a specific Flutter device
```

This script starts the FastAPI backend in a new terminal, waits for `/health` to return 200, then launches Flutter in the current window. When Flutter exits it kills the backend process.

### Running pieces individually

```powershell
# Backend only (from repo root)
cd smart_fit_backend
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
# Eager-load OCR engine at startup (faster first scan request):
$env:SMART_FIT_OCR_EAGER=1; uvicorn main:app --reload

# Flutter only (from repo root)
flutter run --dart-define=BACKEND_URL=http://127.0.0.1:8000 --dart-define=GEMINI_API_KEY=<key>
flutter run -d windows --dart-define=BACKEND_URL=http://127.0.0.1:8000
flutter run -d chrome  --dart-define=BACKEND_URL=http://127.0.0.1:8000
```

### First-time setup

```powershell
# Backend
cd smart_fit_backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
# Copy .env.example → .env and fill in SECRET_KEY + GEMINI_API_KEY

# Flutter (run from repo root)
flutter pub get
```

---

## Flutter Commands

```powershell
flutter analyze          # static analysis / linting
flutter test             # run all unit/widget tests
flutter test test/foo_test.dart  # single test file
flutter pub get          # install/update packages
```

---

## Project Layout

The repo root **is** the Flutter project. There is also a nested `flutter_application_smart_fit/` subdirectory — that is an older copy; ignore it and work from the root.

```
(repo root)
├── lib/                        # Flutter app source
│   ├── main.dart               # Entry point; initialises AppScope + GoRouter
│   ├── app/
│   │   └── app_scope.dart      # InheritedWidget: global theme + locale state
│   ├── config/
│   │   ├── backend_config.dart # BackendConfig.baseUrl — platform-aware URL resolution
│   │   └── oauth_config.dart   # Google / Apple OAuth client IDs (dart-define)
│   ├── router/
│   │   ├── app_router.dart     # GoRouter with 13 named routes
│   │   └── app_routes.dart     # Route path constants
│   ├── screens/                # 18 screens (see Navigation section)
│   ├── models/                 # Dart data classes for API request/response
│   ├── services/               # HTTP clients + business logic
│   ├── parsers/                # Client-side ML Kit → structured metric conversion
│   ├── theme/                  # Material 3 tokens, colors, SmartFitTheme
│   ├── localization/           # EN + AR string files (12 domain files)
│   └── widgets/                # Shared UI components
├── smart_fit_backend/          # FastAPI backend (Python 3.11)
│   ├── main.py                 # All routes, Pydantic models, app startup
│   ├── core.py                 # Constants, logger, feature key list
│   ├── easyocr_router.py       # Separate router mounted at /api/v3/ocr/easyocr
│   ├── ml_service.py           # Stacking ensemble persona classifier (load + infer)
│   ├── ml_engine.py            # Focus zone ML classifier
│   ├── math_engine.py          # Deterministic TDEE + macro calculation
│   ├── matching_engine.py      # Meal + workout recommendation from CSV datasets
│   ├── inbody_extractor.py     # 4-stage OCR orchestrator (PaddleOCR path)
│   ├── easyocr_extractor.py    # EasyOCR extraction path
│   ├── image_preprocessing.py  # OpenCV preprocessing before OCR
│   ├── scan_storage.py         # SQLite — scan_extractions table
│   ├── user_storage.py         # SQLite — users, profiles, plans, logs tables
│   └── data/
│       ├── *.pkl               # Serialised ML model artifacts (joblib)
│       ├── exercises_enhanced.csv
│       ├── advanced_foodcom_labeled_dataset.csv
│       └── smart_fit_scans.sqlite3
├── run.ps1                     # One-command launcher (backend + Flutter)
├── pubspec.yaml                # Flutter dependencies (canonical; includes all packages)
└── test_ocr_accuracy.py        # Standalone OCR accuracy benchmarking script
```

---

## Architecture

### Frontend state & navigation

- **Global state** lives in `AppScope` ([lib/app/app_scope.dart](lib/app/app_scope.dart)), an `InheritedWidget` that holds `themeMode` and `locale`. Both are persisted in `SharedPreferences`. Read it anywhere with `AppScope.of(context)`.
- **Screen-local state** uses plain `StatefulWidget + setState` for loading flags, form state, and one-shot async ops.
- **Navigation** uses GoRouter ([lib/router/app_router.dart](lib/router/app_router.dart)). Typed objects are passed between screens via `state.extra` (e.g., `OcrExtractResult` into `PlanGenerationScreen`). There is no `ShellRoute` / bottom nav widget — each main tab screen is a flat top-level route.
- **Backend URL** is resolved at runtime in `BackendConfig.baseUrl`: `BACKEND_URL` dart-define overrides everything; otherwise web → `127.0.0.1:8000`, Android emulator → `10.0.2.2:8000`.

### Screen flow

```
Landing → Login / Sign Up → Profile Setup → Preferences
                                               ↓
                                         InBody Scan
                                               ↓
                                       Plan Generation  (PlanGenerationScreen)
                                               ↓
                            Home Dashboard / Workout Hub / Nutrition /
                            Progress / AI Coach / Settings  (flat routes)
```

### Backend pipeline

Every InBody scan goes through three sequential backend stages:

1. **OCR** — image → raw text blocks (PaddleOCR via `/ocr/extract`, or EasyOCR via `/api/v3/ocr/easyocr`). On mobile the app first tries Google ML Kit on-device; only if that fails or the platform is web/desktop is the image sent to the backend.
2. **Persona classification** — 12 InBody biomarkers → persona label (`POST /predict`) using a stacking ensemble (XGBoost + LightGBM + CatBoost) stored as joblib `.pkl` files in `data/`.
3. **Plan generation** — `POST /api/v1/generate-plan` runs three sub-stages: math engine (TDEE + macros), focus zone ML classifier, and dataset matching engine (meals from CSV, exercises from CSV).

### OCR engines

| Engine | Route | When used |
|---|---|---|
| Google ML Kit | client-side (no backend call) | Android / iOS native path |
| PaddleOCR | `POST /ocr/extract` | Backend primary; web/desktop |
| EasyOCR | `POST /api/v3/ocr/easyocr` | Parallel alternative pipeline |

### Authentication

Backend issues HS256 JWTs on `POST /auth/login`. The Flutter `AuthService` stores the token in `flutter_secure_storage` (OS keychain). All protected routes require `Authorization: Bearer <token>`. Passwords use bcrypt; legacy SHA-256 hashes are auto-upgraded on next login.

### Key clinical rules in the math engine

- **SMM bias**: `AdjustedTDEE = TDEE + (SMM − populationMean) × 22 kcal/kg` — compensates for higher maintenance calories in muscular users.
- **Intensity reduction**: training load drops to 70% if `ECW/TBW > 0.39` (inflammation) or `Phase Angle < 4.5°` (compromised cellular integrity).
- **Missing field imputation**: TBW, BMR, FFM_of_Trunk, ECW/TBW, and Phase Angle are imputed from established clinical formulas when OCR cannot extract them.

---

## Key Services (Flutter)

| File | Responsibility |
|---|---|
| [lib/services/api_service.dart](lib/services/api_service.dart) | Base HTTP client using `BackendConfig.baseUrl`; attaches JWT |
| [lib/services/auth_service.dart](lib/services/auth_service.dart) | Register / login; stores `user_id` + token in secure storage |
| [lib/services/scan_service.dart](lib/services/scan_service.dart) | OCR upload, extraction confirm, plan generation |
| [lib/services/user_service.dart](lib/services/user_service.dart) | Dashboard, plan fetch, profile, preferences, progress, workout/meal logging |
| [lib/services/social_auth_service.dart](lib/services/social_auth_service.dart) | Google + Apple OAuth; platform stub pattern for web compatibility |

## Key Backend Modules

| File | Responsibility |
|---|---|
| [smart_fit_backend/main.py](smart_fit_backend/main.py) | All routes; mounts `easyocr_router`; app startup/shutdown |
| [smart_fit_backend/math_engine.py](smart_fit_backend/math_engine.py) | Mifflin-St Jeor, TDEE, SMM bias, goal adjustment, macro split |
| [smart_fit_backend/ml_service.py](smart_fit_backend/ml_service.py) | Loads `.pkl` artifacts; runs persona inference |
| [smart_fit_backend/ml_engine.py](smart_fit_backend/ml_engine.py) | Focus zone classifier |
| [smart_fit_backend/matching_engine.py](smart_fit_backend/matching_engine.py) | Filters CSV datasets for meals (5-slot) and exercises per focus zone |
| [smart_fit_backend/inbody_extractor.py](smart_fit_backend/inbody_extractor.py) | PaddleOCR 4-stage pipeline orchestrator |
| [smart_fit_backend/easyocr_extractor.py](smart_fit_backend/easyocr_extractor.py) | EasyOCR extraction path |
| [smart_fit_backend/user_storage.py](smart_fit_backend/user_storage.py) | SQLite: users, profiles, plans, workout/meal logs |
| [smart_fit_backend/scan_storage.py](smart_fit_backend/scan_storage.py) | SQLite: scan_extractions (OCR results + images) |

---

## Environment Variables / dart-defines

| Variable | Where set | Purpose |
|---|---|---|
| `BACKEND_URL` | `--dart-define` | Override backend base URL (required for physical devices) |
| `GEMINI_API_KEY` | `--dart-define` or `.env` | Gemini AI Coach; never in source |
| `SECRET_KEY` | `smart_fit_backend/.env` | JWT signing secret |
| `SMART_FIT_OCR_EAGER` | shell env | Set to `1` to pre-load PaddleOCR engine at startup |

Copy `smart_fit_backend/.env.example` → `smart_fit_backend/.env` before first run.
