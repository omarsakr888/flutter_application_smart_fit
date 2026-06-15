# Smart Fit — Graduation Project Documentation
### AI-Powered Body Composition Analysis & Personalized Fitness Platform

**Version:** 1.0.0  
**Date:** June 2026  
**Platform:** Cross-platform (Android · iOS · Web · Windows · macOS · Linux)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Motivation & Problem Statement](#2-motivation--problem-statement)
3. [System Architecture Overview](#3-system-architecture-overview)
4. [Technology Stack](#4-technology-stack)
5. [Core Features & Innovations](#5-core-features--innovations)
6. [Frontend Architecture (Flutter)](#6-frontend-architecture-flutter)
7. [Backend Architecture (FastAPI + Python)](#7-backend-architecture-fastapi--python)
8. [Machine Learning Pipeline](#8-machine-learning-pipeline)
9. [OCR Pipeline — InBody Scan Extraction](#9-ocr-pipeline--inbody-scan-extraction)
10. [Recommendation Engine](#10-recommendation-engine)
11. [Data Models & API Reference](#11-data-models--api-reference)
12. [Security Considerations](#12-security-considerations)
13. [Testing Strategy](#13-testing-strategy)
14. [Deployment Guide](#14-deployment-guide)
15. [Limitations & Known Issues](#15-limitations--known-issues)
16. [Recommendations for Future Work](#16-recommendations-for-future-work)
17. [Academic Contribution & Novelty](#17-academic-contribution--novelty)
18. [Full Improvement Plan (Supervisor Roadmap)](#18-full-improvement-plan-supervisor-roadmap)

---

## 1. Executive Summary

**Smart Fit** is a cross-platform, AI-driven fitness transformation system that bridges the gap between medical-grade body composition analysis (InBody bioelectrical impedance scanners) and personalized, actionable fitness planning. 

The system ingests an InBody scan report via a smartphone camera, applies a multi-stage OCR pipeline to extract 12 biomarkers, classifies the user into a physiological persona using a trained stacking ensemble classifier, and generates a deterministic + ML-hybrid nutrition and workout plan — all in under 60 seconds.

**What makes it stand out academically:**
- A clinically-grounded feature set (ECW/TBW ratio, Phase Angle, Skeletal Muscle Mass, Body Fat Mass) drives every recommendation — not generic BMI-only logic.
- The persona classification model is built on a stacking ensemble (XGBoost + LightGBM + CatBoost), not a simple rule engine.
- The OCR pipeline is a 4-stage document understanding system with model-specific templates (InBody 570/270/120) and confidence scoring, with dual-engine fallback (Google ML Kit → PaddleOCR).
- The recommendation engine is a 3-stage pipeline: deterministic math → ML focus-zone classification → dataset matching, yielding fully personalized, biomarker-aware meal and workout plans.

---

## 2. Motivation & Problem Statement

### 2.1 The Gap in Current Fitness Apps

The global fitness app market exceeded $15 billion in 2024. Despite this scale, the vast majority of apps share a fundamental flaw: **they personalize based on demographic proxies** (age, height, weight, gender) rather than direct physiological measurements.

This matters because:
- Two people with identical height, weight, and age can have vastly different body compositions — one may have 30% body fat and low muscle mass, the other 15% body fat and high lean mass.
- Training and nutrition protocols that are optimal for one profile may be counterproductive or even harmful for the other.
- InBody scanners (used in gyms, clinics, hospitals) already collect this precise data — but users receive a paper printout with no actionable plan.

### 2.2 The InBody Opportunity

InBody devices are widely deployed in university gyms, fitness centers, and clinical settings across the Middle East and globally. A single scan produces 20+ biomarkers including:
- **SMM** (Skeletal Muscle Mass) — lean tissue available for training
- **BFM / PBF** (Body Fat Mass / Percent Body Fat) — fat load
- **ECW/TBW** (Extracellular Water / Total Body Water) — inflammation & recovery indicator
- **Phase Angle** — cellular health and integrity marker
- **BMR** (Basal Metabolic Rate) — daily caloric floor

Despite this richness, no consumer-facing app systematically harnesses this data to drive personalized AI recommendations. **Smart Fit fills this gap.**

### 2.3 Research Questions

This project addresses three research questions:
1. Can a multi-stage OCR pipeline reliably extract structured biomarker data from InBody scan printouts across multiple device models?
2. Can a stacking ensemble classifier accurately segment users into physiological personas using InBody biomarkers?
3. Does a biomarker-aware recommendation pipeline produce nutritionally and physiologically superior plans compared to demographic-only baselines?

---

## 3. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SMART FIT SYSTEM                             │
│                                                                     │
│  ┌─────────────────────────┐    ┌───────────────────────────────┐   │
│  │   FLUTTER FRONTEND      │    │    FASTAPI BACKEND            │   │
│  │  (Cross-platform app)   │◄──►│  (Python 3.11 + FastAPI)      │   │
│  │                         │    │                               │   │
│  │  • Landing / Auth       │    │  ┌───────────────────────┐    │   │
│  │  • Profile Setup        │    │  │  OCR PIPELINE         │    │   │
│  │  • InBody Scan Upload   │    │  │  PaddleOCR →          │    │   │
│  │  • Metric Review        │    │  │  Doc Analyser →       │    │   │
│  │  • Home Dashboard       │    │  │  Field Extractor →    │    │   │
│  │  • Workout Hub          │    │  │  Response Builder     │    │   │
│  │  • Nutrition Plans      │    │  └───────────────────────┘    │   │
│  │  • Progress Tracking    │    │  ┌───────────────────────┐    │   │
│  │  • AI Coach Chat        │    │  │  ML PIPELINE          │    │   │
│  │  • Settings (EN/AR)     │    │  │  XGBoost + LightGBM + │    │   │
│  │                         │    │  │  CatBoost Stacking    │    │   │
│  │  State: InheritedWidget │    │  └───────────────────────┘    │   │
│  │  Nav:   GoRouter        │    │  ┌───────────────────────┐    │   │
│  │  Theme: Material 3      │    │  │  RECOMMENDATION ENGINE│    │   │
│  │  i18n:  EN + AR (RTL)   │    │  │  MathEngine →         │    │   │
│  └─────────────────────────┘    │  │  ML Focus Zone →      │    │   │
│                                 │  │  CSV Matching Engine  │    │   │
│  ┌─────────────────────────┐    │  └───────────────────────┘    │   │
│  │  LOCAL OCR (FALLBACK)   │    │  ┌───────────────────────┐    │   │
│  │  Google ML Kit          │    │  │  PERSISTENCE          │    │   │
│  │  (Android / iOS native) │    │  │  SQLite3 ScanStorage  │    │   │
│  └─────────────────────────┘    │  │  SQLite3 UserStorage  │    │   │
│                                 │  └───────────────────────┘    │   │
│                                 └───────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.1 Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Frontend framework | Flutter | Single codebase → 6 platforms; strong animation support for fitness UX |
| Backend framework | FastAPI | Async Python with auto Pydantic validation and OpenAPI docs; low latency |
| ML inference | scikit-learn + XGBoost | Mature, production-stable; model artifacts are small and fast to load |
| OCR engine | PaddleOCR (primary) + ML Kit (fallback) | PaddleOCR excels at dense tabular document text; ML Kit is on-device and free |
| Database | SQLite3 | Sufficient for single-user or small deployment; zero-config; easy to migrate to PostgreSQL |
| State management | InheritedWidget | Lightweight; no external dependency for simple global state (theme, locale) |
| Navigation | GoRouter | Declarative routing with deep-link and nested navigation support |

---

## 4. Technology Stack

### 4.1 Frontend

> **Note:** There are two `pubspec.yaml` files in this repo. The canonical one used by the running app is at `flutter_application_smart_fit/pubspec.yaml`. The root-level `pubspec.yaml` is an older copy that is missing several packages. Always run `flutter pub get` inside `flutter_application_smart_fit/`.

**Production dependencies (`dependencies`):**

| Package | Version | Purpose |
|---|---|---|
| flutter (sdk) | — | Core framework |
| flutter_localizations (sdk) | — | EN/AR i18n support |
| cupertino_icons | ^1.0.8 | iOS-style icons |
| go_router | ^14.6.2 | Declarative navigation & deep links |
| google_fonts | ^6.2.1 | Web-fetched typography |
| google_sign_in | ^7.2.0 | Google OAuth |
| sign_in_with_apple | ^7.0.1 | Apple Sign-In (iOS/macOS + Android web) |
| font_awesome_flutter | ^10.8.0 | Extended icon set |
| http | ^1.2.2 | HTTP client for backend calls |
| image_picker | ^1.1.2 | Camera & gallery access |
| shared_preferences | ^2.3.5 | Key-value local storage (theme, locale) |
| flutter_secure_storage | ^9.2.4 | Store JWT tokens securely in OS keychain |
| fl_chart | ^0.69.0 | Progress charts (SMM, PBF, Phase Angle trends) |
| google_generative_ai | ^0.4.6 | Gemini AI Coach integration |

**Dev dependencies (`dev_dependencies`):**

| Package | Version | Purpose |
|---|---|---|
| flutter_test (sdk) | — | Unit & widget testing framework |
| flutter_lints | ^6.0.0 | Recommended lint rules |

**Packages recommended to add (future enhancement):**

| Package | Version | Why needed |
|---|---|---|
| flutter_riverpod | ^2.6.1 | Recommended state management upgrade for testability |
| dio | ^5.7.0 | Replace `http` for better interceptors, retry logic, and download progress |
| cached_network_image | ^3.4.1 | Cache recipe/exercise images |
| intl | ^0.19.0 | Date/number formatting (needed for scan history timestamps) |

### 4.2 Backend

| Layer | Technology | Version |
|---|---|---|
| API framework | FastAPI | 0.115.6 |
| Server | uvicorn (async ASGI) | 0.34.0 |
| OCR engine | PaddleOCR | 3.4.0 |
| Image processing | OpenCV, Pillow | 4.10 / 11.0 |
| ML — gradient boost | XGBoost, LightGBM, CatBoost | 2.1.3 / 4.5 / 1.2.10 |
| ML — sklearn | scikit-learn | 1.6.1 |
| Data wrangling | pandas, numpy | 2.2.3 / 2.0.2 |
| Model persistence | joblib | 1.4.2 |
| Database | SQLite3 (built-in) | — |
| Validation | Pydantic v2 | (via FastAPI) |

### 4.3 Data Assets

| Asset | Description |
|---|---|
| `ultimate_stacking_classifier.pkl` | Trained stacking ensemble — persona classification |
| `ultimate_feature_columns.pkl` | Feature name list for inference alignment |
| `ultimate_inbody_scaler.pkl` | StandardScaler fit on training InBody data |
| `ultimate_zone_mapping.pkl` | Persona label encoder mapping |
| `exercises_enhanced.csv` | 600+ exercises with focus zone, body part, intensity metadata |
| `advanced_foodcom_labeled_dataset.csv` | Primary meal recommendation database |
| `cleaned_intermediate_dataset.csv` | Fallback meal database |

---

## 5. Core Features & Innovations

### 5.1 Feature Matrix

| Feature | Description | Innovation Level |
|---|---|---|
| InBody Scan OCR | Extract 12+ biomarkers from a photo | High — document-specific pipeline |
| Dual OCR engines | ML Kit (on-device) → PaddleOCR (cloud) | Medium — graceful degradation |
| Manual metric review | Edit extracted values before submission | Medium — corrects OCR errors |
| Persona classification | ML stacking classifier → 4–8 personas | High — biomarker-driven segmentation |
| Deterministic nutrition calc | Mifflin-St Jeor + SMM bias + goal adjust | Medium — clinically grounded |
| Focus zone prediction | ML classifier on biomarkers → 4 zones | High — goes beyond BMI |
| Biomarker-aware intensity | ECW/TBW + Phase Angle → training load | High — clinical marker application |
| Meal planning | 5-slot daily plan from labeled dataset | Medium — dataset-driven |
| Workout planning | Split per focus zone with intensity scaling | Medium |
| Scan history | SQLite persistence + history view | Low |
| EN/AR localization | Full RTL Arabic support | Medium — accessibility |
| Dark mode | Full Material 3 dark theme | Low |
| Multi-platform | iOS, Android, Web, Windows, macOS, Linux | Medium |
| Google / Apple OAuth | Social login with token-based auth | Low–Medium |

### 5.2 Key Differentiators vs. Existing Apps

| Capability | Smart Fit | MyFitnessPal | Fitbod | Generic Apps |
|---|---|---|---|---|
| InBody scan import | ✅ OCR | ❌ | ❌ | ❌ |
| ECW/TBW-based intensity | ✅ | ❌ | ❌ | ❌ |
| Phase Angle consideration | ✅ | ❌ | ❌ | ❌ |
| ML persona classification | ✅ | ❌ | Limited | ❌ |
| Arabic RTL support | ✅ | Partial | ❌ | Varies |
| On-device OCR fallback | ✅ | N/A | N/A | ❌ |
| Open data pipeline | ✅ | ❌ | ❌ | ❌ |

---

## 6. Frontend Architecture (Flutter)

### 6.1 Project Structure

```
lib/
├── main.dart                    # App entry point, AppScope init
├── router/
│   ├── app_router.dart          # GoRouter — 14 named routes
│   └── app_routes.dart          # Route name constants
├── screens/                     # 18 screens
│   ├── landing_screen.dart
│   ├── login_screen.dart
│   ├── create_account_screen.dart
│   ├── profile_setup_screen.dart
│   ├── preferences_screen.dart
│   ├── inbody_scan_screen.dart
│   ├── extraction_review_screen.dart
│   ├── analysis_loading_screen.dart
│   ├── home_dashboard_screen.dart
│   ├── workout_hub_screen.dart
│   ├── nutrition_screen.dart
│   ├── progress_screen.dart
│   ├── ai_coach_screen.dart
│   ├── main_navigation_screen.dart
│   ├── settings_screen.dart
│   ├── client_overview_screen.dart
│   ├── recipe_detail_screen.dart
│   └── placeholder_screen.dart
├── models/
│   ├── extracted_metric.dart    # Single OCR metric + confidence
│   ├── inbody_prediction.dart   # Request/response + scan types
│   ├── plan_result.dart         # WorkoutDay, MealSlot, NutritionMacros, PlanResult
│   └── user_profile.dart        # DashboardData, ProgressData
├── services/
│   ├── api_service.dart         # HTTP client → FastAPI backend
│   ├── auth_service.dart        # Register/login + SharedPreferences persistence
│   ├── user_service.dart        # Dashboard, plan, profile, preferences, progress
│   ├── scan_service.dart        # OCR upload + plan generation (user_id aware)
│   ├── social_auth_service.dart # Google + Apple OAuth
│   └── ml_kit_text_recognition_service.dart
├── parsers/
│   └── inbody_data_parser.dart  # Client-side ML Kit → structured metrics
├── theme/
│   ├── app_colors.dart
│   ├── design_tokens.dart
│   └── smart_fit_theme.dart
├── localization/                # EN + AR string files (12 files)
├── app_scope.dart               # InheritedWidget global state
└── widgets/
    ├── premium_empty_state.dart
    └── shimmer_loading.dart
```

### 6.2 Navigation Flow

```
Landing ──────────────────────────────────────────────────┐
   │                                                       │
   ├──► Login ──────────────────────────────────────────► Main Navigation
   │                                                       │
   └──► Sign Up ──► Profile Setup ──► Preferences ──────► │
                                           │               │
                                    InBody Scan            │
                                           │               │
                                    Extraction Review      │
                                           │               │
                                    Analysis Loading ──────►│
                                                           │
                              ┌────────────────────┐      │
                              │  BOTTOM NAV (5 tab)│◄─────┘
                              ├────────────────────┤
                              │  Home Dashboard    │
                              │  Workout Hub       │
                              │  Nutrition         │
                              │  Progress          │
                              │  AI Coach          │
                              └────────────────────┘
```

### 6.3 State Management Architecture

Smart Fit uses a deliberately minimal state management approach:

- **Global state** (`AppScope` — InheritedWidget): theme mode (light/dark) and locale (EN/AR), both persisted in `SharedPreferences`. This is appropriate because these are truly app-wide, rarely changing values.
- **Screen-local state** (`StatefulWidget + setState`): HTTP loading, form validation, metric editing. This is appropriate for one-off async operations in screens.
- **Navigation state** (`GoRouter`): declarative URL-based routing with typed extra objects for passing scan data between screens.

**Note for supervisors:** For production scale, migrating global state to `Riverpod` or `flutter_bloc` would improve testability and scalability. The current design is correct and clean for the project's scope.

### 6.4 Theme System

The theme implements **Material 3** with:
- Primary brand color: Teal `#0F766E`
- Accent / illustration color: Gold `#C9A227`
- Full light and dark mode support
- Design tokens for spacing (2xs–3xl), border radii, and animation durations
- Haptic feedback utilities for premium interactions

### 6.5 Localization

- Languages: English (`en`) and Arabic (`ar`) with full RTL layout support
- Strategy: Custom locale-based string functions (no `intl` package overhead)
- Persistence: Language code stored in `SharedPreferences`
- 12 separate string files by domain (landing, login, scan, home, navigation, etc.)

---

## 7. Backend Architecture (FastAPI + Python)

### 7.1 Module Structure

```
smart_fit_backend/
├── main.py                      # FastAPI app, all routes, Pydantic models
├── core.py                      # Config constants, logger, feature keys
├── ml_service.py                # Persona classifier (load + infer)
├── ml_engine.py                 # Focus zone ML classifier
├── math_engine.py               # Deterministic TDEE + macro calculator
├── matching_engine.py           # Meal + exercise recommendation engine
├── inbody_extractor.py          # 4-stage OCR orchestrator
├── paddle_ocr_engine.py         # PaddleOCR wrapper with lazy loading
├── document_analyser.py         # Layout detection + InBody model ID
├── field_extractor.py           # Field-specific value extraction
├── response_builder.py          # Unit conversion + response formatting
├── scan_storage.py              # SQLite3 — InBody scan persistence (scan_extractions table)
├── user_storage.py              # SQLite3 — user data (users, profiles, plans, logs tables)
└── network_exception_io.dart    # (copied from frontend for reference)
```

### 7.2 API Endpoints

#### Health & Monitoring

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Returns ML model, OCR, storage, and recommendation engine status |

#### OCR Pipeline

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/ocr/extract` | Extract InBody metrics from uploaded image |
| `GET` | `/ocr/history` | Fetch user's past scans (up to 100) |
| `GET` | `/ocr/history/{scan_id}` | Get single scan detail |
| `POST` | `/ocr/confirm` | Confirm reviewed extraction, persist, and run prediction |

#### Prediction

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/predict` | Classify user persona from 12 InBody features |
| `POST` | `/api/v1/process-inbody-mlkit` | Process ML Kit OCR with clinical imputation for missing fields |

#### Recommendation

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/generate-plan` | Generate full personalized meal + workout plan (stores under `user_id`) |

#### Authentication

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/auth/register` | Create account — hashed password stored in `users` table |
| `POST` | `/auth/login` | Validate credentials — returns `user_id`, `name`, `email` |

#### User Data

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/users/profile` | Save age, gender, height, weight, goal from onboarding |
| `GET` | `/users/profile` | Fetch saved profile |
| `POST` | `/users/preferences` | Save diet type, workout days, notification preferences |
| `GET` | `/users/preferences` | Fetch saved preferences |
| `GET` | `/users/dashboard` | Computed: streak, calories consumed today, next workout/meal, recovery insight |
| `GET` | `/users/plan` | Fetch the latest AI-generated plan for the user |
| `POST` | `/users/log-workout` | Log a completed workout day with RPE score |
| `POST` | `/users/log-meal` | Log an eaten meal slot |
| `GET` | `/users/progress` | Weight/fat/muscle history from confirmed scans |

### 7.3 Request/Response Schemas

**`POST /ocr/extract` — Response:**
```json
{
  "extraction_id": "uuid-string",
  "metrics": [
    { "label": "Weight", "value": 78.5, "unit": "kg", "confidence": 0.97, "feature_key": "Weight" }
  ],
  "missing_fields": ["Phase_Angle"],
  "warnings": ["Low confidence on field: ECW_TBW_Ratio"],
  "layout_template": "InBody570",
  "average_confidence": 0.91
}
```

**`POST /predict` — Request:**
```json
{
  "Age": 24, "Gender": 1, "Height": 175, "Weight": 78.5,
  "SMM": 34.2, "BMR": 1780, "FFM_of_Trunk": 28.1,
  "TBW": 45.6, "ECW_TBW_Ratio": 0.385, "Phase_Angle": 5.8,
  "BFM": 15.3, "PBF": 19.5, "User_Goal": "Muscle Gain"
}
```

**`POST /api/v1/generate-plan` — Response (abridged):**
```json
{
  "focus_zone": "Upper Body Strength",
  "intensity_multiplier": 1.0,
  "macros": { "calories": 2650, "protein_g": 185, "carbs_g": 290, "fat_g": 75 },
  "daily_meals": {
    "breakfast": { "name": "...", "calories": 662, "protein": "...", "recipe_url": "..." },
    "snack_1": { ... }, "lunch": { ... }, "snack_2": { ... }, "dinner": { ... }
  },
  "workout_split": {
    "Monday": [{ "exercise": "Barbell Bench Press", "sets": 4, "reps": "8-10", "rest_sec": 90 }],
    ...
  }
}
```

---

## 8. Machine Learning Pipeline

### 8.1 Persona Classification Model

**Architecture:** Stacking Ensemble

The model combines three gradient-boosted tree classifiers:
- **XGBoost** — strong on feature interactions
- **LightGBM** — fast, handles sparse features
- **CatBoost** — robust to categorical features (Gender, User_Goal)

A meta-learner (logistic regression or another tree) combines the base model outputs.

**Input Features (12):**

| Feature | Clinical Meaning | Range (typical) |
|---|---|---|
| Age | Chronological age | 15–80 years |
| Gender | Biological sex | 0 (F) / 1 (M) |
| Height | Body height | 140–210 cm |
| Weight | Total body weight | 40–150 kg |
| SMM | Skeletal Muscle Mass | 15–55 kg |
| BMR | Basal Metabolic Rate | 1000–2500 kcal |
| FFM_of_Trunk | Fat-Free Mass — trunk | 15–40 kg |
| TBW | Total Body Water | 25–60 L |
| ECW_TBW_Ratio | Extracellular Water / TBW | 0.35–0.42 |
| Phase_Angle | Cellular integrity | 3.0–8.0° |
| BFM | Body Fat Mass | 5–60 kg |
| PBF | Percent Body Fat | 5–50 % |

**Output:** Predicted persona (e.g., "Athletic Lean", "Obese High Risk", "Muscle Builder") + confidence score.

**Model Artifacts (serialized with joblib):**
- `ultimate_stacking_classifier.pkl` — trained model
- `ultimate_inbody_scaler.pkl` — StandardScaler (fit on training set)
- `ultimate_feature_columns.pkl` — feature column order
- `ultimate_zone_mapping.pkl` — label encoding map

### 8.2 Focus Zone Classifier (ML Engine)

A secondary ML classifier maps the same 12 biomarkers to one of **4 focus zones**:

| Zone | Clinical Profile | Recommended Focus |
|---|---|---|
| Core Stability | Moderate fat, low Phase Angle | Stability, endurance, recovery |
| Lower Body Power | High SMM, lower body dominance | Compound lower body, hypertrophy |
| Upper Body Strength | High upper SMM, moderate fat | Press/pull movements, strength |
| Balanced Recovery | Elevated ECW/TBW, inflammation markers | Active recovery, mobility |

### 8.3 Clinical Imputation (Missing Fields)

When the OCR cannot extract a field, the backend applies clinically established imputation:
- **TBW** from Weight × 0.60 (males) or × 0.50 (females)
- **BMR** from Mifflin-St Jeor: `(10 × W) + (6.25 × H) − (5 × Age) + 5` (males)
- **FFM_of_Trunk** from SMM × 0.55 (heuristic ratio)
- **ECW/TBW** default: 0.38 (population average)
- **Phase Angle** default: 5.5° (population average)

This ensures the pipeline is robust even with partial scans.

### 8.4 Deterministic Nutrition Calculator (Math Engine)

**Step 1 — BMR:**  
Mifflin-St Jeor equation:
```
BMR_male   = 10W + 6.25H − 5A + 5
BMR_female = 10W + 6.25H − 5A − 161
```

**Step 2 — TDEE (Total Daily Energy Expenditure):**
```
TDEE = BMR × ActivityMultiplier
```
Activity multipliers based on `preferred_days` per week:

| Days/week | Multiplier |
|---|---|
| 1 | 1.20 (sedentary) |
| 2 | 1.375 |
| 3 | 1.55 |
| 4 | 1.725 |
| 5–6 | 1.90 (very active) |

**Step 3 — SMM Bias Correction:**
```
AdjustedTDEE = TDEE + (SMM − PopulationMeanSMM) × 22 kcal/kg
```
This acknowledges that individuals with higher skeletal muscle mass have higher maintenance calories per unit weight — something BMI-based apps miss entirely.

**Step 4 — Goal-Aware Caloric Target:**

| Goal | Adjustment |
|---|---|
| Balanced / Recovery | ±0% (maintenance) |
| Core Stability | −5% (mild deficit) |
| Lower Body Power | +5% (mild surplus) |
| Upper Body Strength | +8% (moderate surplus) |

**Step 5 — Macro Split:**  
Macros are distributed based on goal zone, with protein targets scaled to body weight.

**Step 6 — Intensity Flag:**  
Training intensity is reduced to 70% if:
- `ECW/TBW > 0.39` (inflammation / water retention signal)
- `Phase Angle < 4.5°` (compromised cellular integrity)

This is a clinically significant innovation — most fitness apps have no mechanism to detect physiological states where heavy training is contraindicated.

---

## 9. OCR Pipeline — InBody Scan Extraction

### 9.1 Architecture (4 Stages)

```
Input Image (JPEG/PNG)
        │
        ▼
┌───────────────────┐
│  Stage 1: OCR     │  PaddleOCR → raw text blocks with bounding boxes + confidence
│  Engine           │
└─────────┬─────────┘
          ▼
┌───────────────────┐
│  Stage 2: Doc     │  Detect InBody model (570 / 270 / 120)
│  Analyser         │  Detect units (metric / imperial)
└─────────┬─────────┘
          ▼
┌───────────────────┐
│  Stage 3: Field   │  12 configurable field descriptors
│  Extractor        │  Positional + keyword matching
│                   │  Unit normalization (lbs→kg, in→cm)
│                   │  Per-field confidence scoring
└─────────┬─────────┘
          ▼
┌───────────────────┐
│  Stage 4: Response│  Validate ranges, flag outliers
│  Builder          │  Track imputed vs. extracted fields
│                   │  Return JSON with warnings
└───────────────────┘
```

### 9.2 Dual-Engine Strategy

| Condition | OCR Engine Used |
|---|---|
| Android / iOS in-app | Google ML Kit (on-device, free, fast) |
| Web / Desktop in-app | Fallback to backend |
| Backend (always) | PaddleOCR (superior on dense tables) |

The ML Kit path runs entirely on-device — **no image leaves the phone** if the extraction succeeds. Only if ML Kit fails or the user is on web/desktop does the image get sent to the backend.

### 9.3 Template-Specific Extraction

Different InBody device models produce different report layouts. The system detects and adapts to:
- **InBody 570** — most detailed, 20+ fields, clinical layout
- **InBody 270** — mid-tier gym scanner, simplified layout
- **InBody 120** — entry-level, fewer biomarkers
- **ML Kit fallback** — generic extraction mode

### 9.4 Confidence & Warning System

Each extracted field receives:
- A **confidence score** (0.0–1.0) from PaddleOCR's character recognition
- A **field validation check** against clinically plausible ranges
- A **warning tag** if the value is imputed, low-confidence, or out of range

The `ExtractionReviewScreen` surfaces these warnings so users can manually correct values before final submission.

---

## 10. Recommendation Engine

### 10.1 Three-Stage Pipeline

```
InBody metrics + preferences
          │
          ▼
┌─────────────────────┐
│  Stage 1:           │
│  Math Engine        │  → TDEE, macros, intensity_multiplier
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Stage 2:           │
│  ML Focus Zone      │  → focus_zone (one of 4 zones)
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Stage 3:           │
│  Matching Engine    │  → daily_meals (5 slots) + workout_split
└─────────────────────┘
```

### 10.2 Meal Matching

**Daily caloric distribution across 5 slots:**

| Slot | % of TDEE | Target (2500 kcal example) |
|---|---|---|
| Breakfast | 25% | 625 kcal |
| Snack 1 | 10% | 250 kcal |
| Lunch | 30% | 750 kcal |
| Snack 2 | 10% | 250 kcal |
| Dinner | 25% | 625 kcal |

Meals are filtered from the FoodCom dataset by:
- Caloric proximity to slot target (±15%)
- Diet type (standard, vegetarian, vegan, keto, etc.)
- Health score threshold
- Average recipe rating

### 10.3 Exercise Matching

Exercises are filtered from the enhanced exercise dataset by:
- Focus zone alignment
- Muscle group balance across the week
- Intensity scaling via `intensity_multiplier`
- Sets/reps auto-calculated based on goal (strength: 4×6, hypertrophy: 3×12, endurance: 3×15)

---

## 11. Data Models & API Reference

### 11.1 Core Data Types

**`ExtractedMetric`**
```dart
class ExtractedMetric {
  final String label;       // e.g., "Weight"
  final String unit;        // e.g., "kg"
  final double value;
  final double confidence;  // 0.0–1.0
  final String featureKey;  // e.g., "Weight" (maps to ML model input)
}
```

**`InBodyPredictionRequest`**
```dart
class InBodyPredictionRequest {
  final double age, height, weight, smm, bmr;
  final double ffmOfTrunk, tbw, ecwTbwRatio, phaseAngle;
  final double bfm, pbf;
  final int gender; // 0 = female, 1 = male
  final String userGoal;
}
```

**`OcrExtractionResult`**
```dart
class OcrExtractionResult {
  final String extractionId;
  final List<ExtractedMetric> metrics;
  final List<String> missingFields;
  final List<String> warnings;
  final String layoutTemplate;
  final double averageConfidence;
}
```

**`PlanResult`** (lib/models/plan_result.dart)
```dart
class PlanResult {
  final String focusZone;
  final double intensityMultiplier;
  final NutritionMacros macros;
  final List<WorkoutDay> workoutSplit;
  final List<MealSlot> dailyMeals;
}
```

**`DashboardData`** (lib/models/user_profile.dart)
```dart
class DashboardData {
  final String userName;
  final int streak;
  final double caloriesConsumed;   // today's logged calories
  final double caloriesTarget;     // from current plan
  final int hydrationCups;
  final String nextWorkout;        // e.g. "Day 2 — Upper Body"
  final String nextMeal;           // e.g. "Lunch"
  final String recoveryInsight;    // from plan (intensity note)
}
```

**`ProgressData`** (lib/models/user_profile.dart)
```dart
class ProgressData {
  final List<double> weightHistory;
  final List<double> fatHistory;
  final List<double> muscleHistory;
  final List<String> scanDates;
  final double? fatLostKg;
  final double? muscleGainedKg;
}
```

### 11.2 API Service Configuration

```dart
// api_service.dart
static const String _baseUrl = kIsWeb
    ? 'http://127.0.0.1:8000'      // Web / Desktop
    : 'http://10.0.2.2:8000';      // Android emulator
```

---

## 12. Security Considerations

### 12.1 Current State

| Area | Current Implementation | Risk Level |
|---|---|---|
| Authentication | JWT tokens (signed HS256) + bcrypt passwords + Google/Apple OAuth | Low |
| API security | `Authorization: Bearer <token>` required on all protected routes | Low |
| Password hashing | bcrypt via `bcrypt` package; legacy SHA-256 hashes auto-upgraded on login | Low |
| Rate limiting | 10 login / 5 register attempts per IP per minute (in-memory) | Low |
| JWT storage | OS keychain via `flutter_secure_storage` | Low |
| Data at rest | SQLite plaintext | Medium |
| Image transmission | HTTP (not HTTPS) to localhost | Low (localhost only) |
| Secret management | Gemini key via `--dart-define`; JWT secret via `.env` (excluded from Git) | Low |

### 12.2 Remaining Gaps (Not Production-Ready)

1. **HTTP instead of HTTPS.** Production deployment must use TLS with a reverse proxy (nginx + Let's Encrypt).

2. **CORS allows all origins (`*`).** Tighten to specific origin(s) before external deployment.

3. **SQLite has no row-level security.** A compromised `user_id` allows cross-user data access. Production fix: PostgreSQL with row-level security policies.

4. **In-memory rate limiting resets on server restart.** For production, replace with Redis-backed rate limiting to survive restarts and horizontal scaling.

5. **No audit logging.** Auth events and data mutations are not logged for forensic use. Add structured logging with timestamps before production.

For a full list of what is and is not secured, see `README_SECURITY.md`.

---

## 13. Testing Strategy

### 13.1 Current Testing State

The project currently has minimal automated tests. For a graduation project, the following test pyramid is recommended:

### 13.2 Recommended Test Pyramid

```
          ▲
         / \
        /E2E\          Integration tests (few)
       /─────\         Full scan flow: image → OCR → predict → plan
      / Integ \
     /─────────\       Unit tests (many)
    /  Unit     \      Math engine, field extractor, parsers
   /─────────────\
  /   Static      \    Dart analyzer, Flutter linting
 /─────────────────\
```

### 13.3 Critical Test Cases

**Math Engine:**
- Male, 25yo, 80kg, 175cm, SMM=35kg, 5 days/week → verify TDEE within ±5% of manual calc
- ECW/TBW=0.40 → verify intensity_multiplier = 0.70
- Phase Angle=4.0 → verify intensity_multiplier = 0.70

**OCR Pipeline:**
- InBody570 sample image → verify all 12 fields extracted with confidence > 0.80
- Partial scan (missing Phase Angle) → verify imputation applied and warning surfaced

**Persona Classifier:**
- Load model artifacts → verify model loads without error
- Pass known input → verify output is one of the valid persona labels

**API Endpoints:**
- `POST /predict` with valid payload → verify 200 + persona in response
- `POST /predict` with missing fields → verify 422 validation error
- `POST /ocr/extract` with non-image file → verify error handled gracefully

---

## 14. Deployment Guide

### 14.1 Backend Setup

```bash
# 1. Navigate to backend directory
cd smart_fit_backend

# 2. Create virtual environment
python -m venv venv
venv\Scripts\activate    # Windows
source venv/bin/activate # macOS/Linux

# 3. Install dependencies
pip install -r requirements.txt

# 4. Verify model artifacts are present
ls data/  # Should contain *.pkl files and smart_fit_scans.sqlite3

# 5. Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Optional: Eager-load OCR engine at startup (faster first request)
SMART_FIT_OCR_EAGER=1 uvicorn main:app --reload
```

### 14.2 Frontend Setup

```bash
# 1. Navigate to Flutter app
cd flutter_application_smart_fit

# 2. Get dependencies
flutter pub get

# 3. Run on target platform
flutter run -d android    # Android device/emulator
flutter run -d chrome     # Web browser
flutter run -d windows    # Windows desktop

# 4. Run with OAuth configured
flutter run -d android \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<your_client_id> \
  --dart-define=APPLE_SERVICE_ID=<your_service_id> \
  --dart-define=APPLE_REDIRECT_URI=<your_redirect_uri>
```

### 14.3 Production Deployment

For production, the recommended stack is:
- **Backend:** Docker container with FastAPI + uvicorn, behind nginx reverse proxy with HTTPS
- **Database:** PostgreSQL (migrate from SQLite) with row-level security
- **Frontend:** Flutter Web → Firebase Hosting or Vercel; Mobile → App Store / Play Store
- **Model serving:** Consider moving to TorchServe or TFServing for higher throughput

---

## 15. Limitations & Known Issues

| # | Limitation | Impact | Suggested Fix |
|---|---|---|---|
| 1 | Localhost-only API URL | Cannot demo on real device without network config | Use environment-based URL config |
| 2 | Stale recommendation data (CSV) | Meals/exercises may lack variety over time | Integrate live recipe API (Spoonacular, Edamam) |
| 3 | Single language OCR | PaddleOCR Arabic support is limited | Fine-tune PaddleOCR on Arabic InBody scans |
| 4 | No offline mode | App fails without backend | Cache last scan + plan locally |
| 5 | No model retraining pipeline | Model improves only with manual re-training | Add user feedback loop + periodic retraining |
| 6 | SQLite concurrency | Fails under multi-user load | Migrate to PostgreSQL with async driver |
| 7 | In-memory rate limiting | Resets on server restart; not suitable for multi-instance deploys | Redis-backed rate limiting |
| 8 | Progress charts show static data | No multi-scan trend line yet (only latest scan shown) | Store multiple scan records and plot time series |

---

## 16. Recommendations for Future Work

### 16.1 Short-Term (0–3 months)

1. ~~**Implement AI Coach (ChatGPT/Claude API integration)**~~ **✅ Done — Gemini AI integrated**  
   `ai_coach_screen.dart` now calls Google Gemini (`google_generative_ai ^0.4.6`) with a system prompt seeded from the user's InBody data and current plan. Key is injected via `--dart-define=GEMINI_API_KEY=...` — never in source.

2. ~~**Progress Charts**~~ **✅ Done — fl_chart integrated**  
   `progress_screen.dart` uses `fl_chart ^0.69.0` to render SMM, PBF, and Phase Angle data. An "Start InBody Scan" CTA is shown when no scan data exists yet.

3. ~~**Backend Authentication**~~ **✅ Done — JWT + bcrypt + rate limiting**  
   FastAPI backend issues signed JWTs (HS256) on login; all protected routes require `Authorization: Bearer`. Passwords use bcrypt with automatic upgrade from legacy SHA-256. Per-IP rate limiting: 10 login / 5 register requests per minute.

4. **Fix API URL Configuration**  
   Replace hardcoded `127.0.0.1:8000` with a build-time environment variable so the app can connect to a hosted backend during demos.

5. **Populate Scan History UI**  
   The backend stores scan history but the frontend dashboard needs to render historical trends, not just the latest scan.

### 16.2 Medium-Term (3–6 months)

6. **Fine-tune Persona Classification Model**  
   Collect labeled InBody data from willing participants (gym members with known fitness levels) to improve the classifier's real-world accuracy. Document precision/recall per class — supervisors will ask.

7. **A/B Test Recommendation Quality**  
   Compare recommendations generated by Smart Fit vs. generic apps using a user satisfaction survey. This creates academic evidence for the paper.

8. **Multi-language OCR**  
   Train or fine-tune PaddleOCR on Arabic InBody scan printouts for the Saudi/Egyptian market.

9. **Offline-first Architecture**  
   Cache the last successful plan in local storage. Allow the app to function without an active backend connection (except for initial scan upload).

10. **Firebase / Supabase Authentication**  
    Replace the OAuth-only flow with a proper user database so the app supports registration, login, and multi-device sync.

### 16.3 Long-Term (6–12 months)

11. **Wearable Integration**  
    Connect to Apple HealthKit and Google Fit to supplement InBody data with daily step count, heart rate variability, and sleep data for more dynamic recommendations.

12. **Longitudinal ML Model**  
    Train a time-series model on repeated scans to predict body composition changes over 4–8 weeks given adherence to the generated plan.

13. **Trainer/Client Portal**  
    The `client_overview_screen.dart` suggests a trainer-facing view. Build this out so certified trainers can manage multiple clients' Smart Fit plans.

14. **Publish Dataset & Model**  
    If data consent allows, publish the anonymized InBody dataset and stacking classifier on Kaggle/HuggingFace. This creates a citable academic contribution.

---

## 17. Academic Contribution & Novelty

This project makes the following original contributions:

### 17.1 Engineering Contributions

1. **Document-Aware InBody OCR Pipeline**  
   A 4-stage OCR system with model-specific templates (InBody 570/270/120), clinical range validation, and confidence-scored output — not a generic text extractor. The dual-engine architecture (ML Kit on-device → PaddleOCR cloud) is a practical engineering innovation.

2. **Biomarker-Aware Intensity Modulation**  
   Using ECW/TBW ratio and Phase Angle — clinical markers of inflammation and cellular integrity — to dynamically reduce training intensity is, to our knowledge, not implemented in any consumer fitness app. This bridges clinical exercise physiology with consumer software.

3. **Stacking Ensemble for Fitness Persona Classification**  
   Combining XGBoost, LightGBM, and CatBoost in a stacking ensemble trained specifically on InBody biomarkers for persona segmentation is a novel application of ensemble methods in the fitness domain.

### 17.2 Societal Impact

- Democratizes InBody scan data: users who receive a paper scan result at their gym now get an actionable plan.
- Arabic RTL support targets an underserved market (350M Arabic speakers).
- Open architecture: the backend can be self-hosted, making it accessible without subscription fees.

### 17.3 Potential for Publication

The following aspects are publishable in conference proceedings (e.g., IEEE ICHI, ACM HEALTH, or engineering conferences):
- The InBody OCR pipeline with confidence scoring (system paper)
- ECW/TBW + Phase Angle based intensity modulation (clinical computing paper)
- The stacking ensemble for persona classification with benchmark results (ML paper)

---

## 18. Full Improvement Plan (Supervisor Roadmap)

The following table is a phased plan organized by priority and effort, suitable for presenting to supervisors.

### Phase 1 — Demo Readiness (Before Submission)

| # | Task | Priority | Effort | Status |
|---|---|---|---|---|
| 1 | Implement AI Coach screen with Gemini API | Critical | 2–3 days | **Done — Gemini AI Coach** |
| 2 | Add progress charts (fl_chart) | High | 1–2 days | **Done — fl_chart integrated** |
| 3 | Fix API URL to be environment-configurable | Critical | 2 hours | Hardcoded |
| 4 | Add JWT auth middleware to backend | High | 1 day | **Done — JWT + bcrypt + rate limiting** |
| 5 | Populate scan history view with graphs | High | 1–2 days | Partial |
| 6 | Finalize workout hub screen content | Medium | 1 day | **Done — live from plan** |
| 7 | Finalize nutrition screen content | Medium | 1 day | **Done — live from plan** |
| 8 | Connect generate-plan + all screens to backend | Critical | 1–2 days | **Done — fully wired** |

### Phase 2 — Academic Rigor (For Defense)

| # | Task | Priority | Effort |
|---|---|---|---|
| 9 | Benchmark OCR accuracy on 20+ InBody scans | Critical | 2–3 days |
| 10 | Benchmark classifier (precision, recall, F1 per persona) | Critical | 1–2 days |
| 11 | Compare Smart Fit plans vs. generic app plans (user survey) | High | 1 week |
| 12 | Write evaluation methodology section of report | Critical | 2–3 days |
| 13 | Document ML model training procedure and data split | High | 1 day |

### Phase 3 — Production (Post-Graduation)

| # | Task | Effort |
|---|---|---|
| 14 | Migrate to Firebase Auth + Firestore | 1 week |
| 15 | Migrate SQLite → PostgreSQL | 2 days |
| 16 | Docker + nginx + HTTPS deployment | 2–3 days |
| 17 | App Store + Play Store submission | 3–5 days |
| 18 | Arabic OCR support | 2–3 weeks |
| 19 | Wearable API integration | 2–4 weeks |

---

## Appendix A — Glossary

| Term | Definition |
|---|---|
| InBody | Brand of bioelectrical impedance analysis (BIA) devices for body composition measurement |
| SMM | Skeletal Muscle Mass — mass of muscles attached to the skeleton |
| BMR | Basal Metabolic Rate — calories burned at complete rest |
| BFM | Body Fat Mass — absolute fat weight in kilograms |
| PBF | Percent Body Fat — fat as a percentage of total body weight |
| TBW | Total Body Water — total water content of the body |
| ECW | Extracellular Water — water outside cells; elevated levels indicate inflammation |
| ECW/TBW | Ratio of ECW to TBW; values >0.39 may indicate systemic inflammation or poor recovery |
| Phase Angle | Electrical phase shift from BIA; values <4.5° may indicate compromised cellular health |
| FFM | Fat-Free Mass — total mass minus fat |
| TDEE | Total Daily Energy Expenditure — total calories burned in a day |
| OCR | Optical Character Recognition — converting image text to machine-readable text |
| PaddleOCR | Open-source OCR framework by Baidu, excels at dense document layouts |
| ML Kit | Google's on-device ML SDK for Android/iOS, includes text recognition |
| Stacking Ensemble | ML technique combining multiple models where a meta-learner aggregates base model outputs |
| RTL | Right-to-Left — text direction for Arabic, Hebrew, etc. |

---

## Appendix B — Quick Reference: Key Files

| File | Purpose |
|---|---|
| [lib/main.dart](flutter_application_smart_fit/lib/main.dart) | App entry point |
| [lib/router/app_router.dart](flutter_application_smart_fit/lib/router/app_router.dart) | All named routes |
| [lib/services/auth_service.dart](flutter_application_smart_fit/lib/services/auth_service.dart) | Register/login + SharedPreferences session |
| [lib/services/user_service.dart](flutter_application_smart_fit/lib/services/user_service.dart) | Dashboard, plan, profile, progress API calls |
| [lib/services/scan_service.dart](flutter_application_smart_fit/lib/services/scan_service.dart) | OCR upload + plan generation |
| [lib/services/api_service.dart](flutter_application_smart_fit/lib/services/api_service.dart) | Base HTTP client |
| [lib/models/plan_result.dart](flutter_application_smart_fit/lib/models/plan_result.dart) | WorkoutDay, MealSlot, NutritionMacros, PlanResult |
| [lib/models/user_profile.dart](flutter_application_smart_fit/lib/models/user_profile.dart) | DashboardData, ProgressData |
| [lib/models/inbody_prediction.dart](flutter_application_smart_fit/lib/models/inbody_prediction.dart) | OCR request/response models |
| [lib/app_scope.dart](flutter_application_smart_fit/lib/app_scope.dart) | Global state (theme, locale) |
| [smart_fit_backend/main.py](smart_fit_backend/main.py) | All API endpoints (auth + OCR + plan + user data) |
| [smart_fit_backend/user_storage.py](smart_fit_backend/user_storage.py) | SQLite — users, profiles, plans, workout/meal logs |
| [smart_fit_backend/scan_storage.py](smart_fit_backend/scan_storage.py) | SQLite — InBody scan extractions |
| [smart_fit_backend/math_engine.py](smart_fit_backend/math_engine.py) | TDEE + macro calculator |
| [smart_fit_backend/ml_service.py](smart_fit_backend/ml_service.py) | Persona classifier |
| [smart_fit_backend/inbody_extractor.py](smart_fit_backend/inbody_extractor.py) | 4-stage OCR orchestrator |
| [smart_fit_backend/matching_engine.py](smart_fit_backend/matching_engine.py) | Meal + workout recommender |

---

*Documentation generated: June 2026 | Smart Fit v1.0.0*
