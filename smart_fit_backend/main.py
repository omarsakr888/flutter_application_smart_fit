from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager
from dataclasses import asdict
from typing import Any, Literal

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Form, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic import ValidationError

from auth.jwt import create_access_token, verify_token
from core import REQUIRED_INPUT_FEATURES, configure_logging

load_dotenv()
from template_extractor import TemplateExtractor
from math_engine import MathEngine
from matching_engine import MatchingEngine
from delta_engine import caloric_modifier, compute_delta
from ml_engine import predict_focus_zone
from ml_service import PredictionRequest, PredictionService
from ocr_schemas import ConfirmScanRequest
from ocr_service import OcrService
from easyocr_engine import EasyOcrEngine
from admin_router import router as admin_router
from easyocr_router import build_easyocr_router
from scan_storage import ScanStorage
from user_storage import UserStorage

logger = configure_logging()
prediction_service = PredictionService()
scan_storage = ScanStorage()
user_storage = UserStorage()
ocr_engine = EasyOcrEngine()
ocr_service = OcrService(
    engine=ocr_engine,
    extractor=TemplateExtractor(),
    storage=scan_storage,
)
math_engine     = MathEngine()
matching_engine = MatchingEngine()


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        scan_storage.initialize()
        user_storage.initialize()
        try:
            prediction_service.load()
        except Exception:
            logger.exception("ML artifacts are unavailable; prediction endpoints will return 503")
            if os.getenv("SMART_FIT_STRICT_ML_STARTUP", "0") == "1":
                raise
        if os.getenv("SMART_FIT_OCR_EAGER", "0") == "1":
            ocr_engine.load()
    except Exception:
        logger.exception("Failed to initialize Smart Fit backend")
        raise
    yield


app = FastAPI(
    title="Smart Fit AI Backend",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


# ─── JWT authentication dependency ───────────────────────────────────────────

_bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> str:
    """Extract and verify the Bearer JWT; return the user_id (sub claim)."""
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Authentication required. Include 'Authorization: Bearer <token>' header.",
        )
    try:
        return verify_token(credentials.credentials)
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token. Please log in again.",
        )


app.include_router(build_easyocr_router(get_current_user, scan_storage, ocr_service))
app.include_router(admin_router)


# ─── Exception handlers ───────────────────────────────────────────────────────

@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"status": "error", "message": exc.detail},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled backend error: %s", exc)
    return JSONResponse(
        status_code=500,
        content={"status": "error", "message": "Smart Fit backend is temporarily unavailable."},
    )


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ready" if prediction_service.ready else "loading",
        "ml_model": "ready" if prediction_service.ready else "loading",
        "ocr_engine": "ready" if ocr_engine.ready else "lazy",
        "storage": "ready",
        "recommendation_engine": "ready" if matching_engine.ready else "datasets_missing",
    }


@app.post("/predict")
def predict(payload: PredictionRequest) -> dict[str, str | float]:
    try:
        return prediction_service.predict_request(payload)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except (ValueError, ValidationError) as exc:
        logger.warning("Invalid prediction input: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Prediction failed")
        raise HTTPException(status_code=500, detail="Unable to generate prediction.") from exc


@app.post("/ocr/extract")
async def extract_inbody_scan(
    file: UploadFile = File(...),
    include_blocks: bool = Form(False),
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    try:
        image_bytes = await file.read()
        return ocr_service.extract_scan(
            image_bytes=image_bytes,
            filename=file.filename,
            content_type=file.content_type,
            user_id=user_id,
            include_blocks=include_blocks,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Unable to extract InBody scan.") from exc


@app.post("/ocr/confirm")
def confirm_inbody_scan(
    payload: ConfirmScanRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    try:
        features = payload.normalized_features()
        prediction = prediction_service.predict_features(features)
        scan_id = scan_storage.confirm_scan(
            extraction_id=payload.extraction_id,
            user_id=user_id,  # from JWT, not body
            features=features,
            prediction=prediction,
        )
        return {
            "status": "success",
            "scan_id": scan_id,
            "features": features,
            "prediction": prediction,
        }
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except (ValueError, ValidationError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Scan confirmation failed")
        raise HTTPException(status_code=500, detail="Unable to confirm scan.") from exc


@app.get("/ocr/history")
def scan_history(
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    scans = scan_storage.list_history(user_id=user_id, limit=limit)
    return {"status": "success", "scans": scans}


@app.get("/ocr/history/{scan_id}")
def scan_history_detail(
    scan_id: str,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    scan = scan_storage.get_scan(scan_id=scan_id, user_id=user_id)
    if scan is None:
        raise HTTPException(status_code=404, detail="Scan not found.")
    return {"status": "success", "scan": scan}


# ═══════════════════════════════════════════════════════════════════════════════
# Recommendation Engine — /api/v1/generate-plan
# ═══════════════════════════════════════════════════════════════════════════════
class MlKitInBodyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    extraction_id: str | None = None
    user_id: str = "local-user"
    features: dict[str, float | int | str | None]


_IMPUTABLE_FEATURES = {
    "TBW_(Total_Body_Water)",
    "ECW/TBW",
    "50kHz-Whole_Body_Phase_Angle",
}

_FIELD_LABELS = {
    "Age": "Age",
    "Gender": "Gender",
    "Height": "Height",
    "Weight": "Weight",
    "SMM_(Skeletal_Muscle_Mass)": "Skeletal Muscle Mass",
    "BMR_(Basal_Metabolic_Rate)": "Basal Metabolic Rate",
    "FFM_of_Trunk": "FFM of Trunk",
    "TBW_(Total_Body_Water)": "Total Body Water",
    "ECW/TBW": "ECW/TBW",
    "50kHz-Whole_Body_Phase_Angle": "Whole Body Phase Angle",
    "BFM_(Body_Fat_Mass)": "Body Fat Mass",
    "PBF_(Percent_Body_Fat)": "Percent Body Fat",
}

_FIELD_UNITS = {
    "Age": "yrs",
    "Gender": "0/1",
    "Height": "cm",
    "Weight": "kg",
    "SMM_(Skeletal_Muscle_Mass)": "kg",
    "BMR_(Basal_Metabolic_Rate)": "kcal",
    "FFM_of_Trunk": "kg",
    "TBW_(Total_Body_Water)": "L",
    "ECW/TBW": "ratio",
    "50kHz-Whole_Body_Phase_Angle": "deg",
    "BFM_(Body_Fat_Mass)": "kg",
    "PBF_(Percent_Body_Fat)": "%",
}


@app.post("/api/v1/process-inbody-mlkit")
def process_inbody_mlkit(
    payload: MlKitInBodyRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    try:
        features, field_metadata = _normalize_and_impute_mlkit_features(payload.features)
        prediction = prediction_service.predict_features(features)
        scan_id = scan_storage.confirm_scan(
            extraction_id=payload.extraction_id,
            user_id=user_id,  # from JWT, not body
            features=features,
            prediction=prediction,
            imputation_metadata=field_metadata,
        )
        return {
            "status": "success",
            "scan_id": scan_id,
            "features": features,
            "fields": field_metadata,
            "prediction": prediction,
        }
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except (ValueError, ValidationError) as exc:
        logger.warning("Invalid ML Kit InBody input: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("ML Kit InBody processing failed")
        raise HTTPException(status_code=500, detail="Unable to process verified InBody data.") from exc


def _normalize_and_impute_mlkit_features(
    raw_features: dict[str, float | int | str | None],
) -> tuple[dict[str, float | str], dict[str, dict[str, Any]]]:
    values: dict[str, float | str | None] = {}
    was_missing: dict[str, bool] = {}
    for key in REQUIRED_INPUT_FEATURES:
        if key == "User_Goal":
            goal = raw_features.get(key)
            values[key] = str(goal).strip() if goal not in {None, ""} else "Balanced/Recovery"
            continue
        was_missing[key] = raw_features.get(key) in {None, ""}
        values[key] = _nullable_float(raw_features.get(key), key)

    _impute_clinical_fields(values)

    missing = [
        key
        for key in REQUIRED_INPUT_FEATURES
        if key != "User_Goal" and values.get(key) is None
    ]
    if missing:
        raise ValueError(
            "Missing required non-imputable fields after clinical imputation: "
            + ", ".join(missing)
        )

    features = {
        key: str(values[key]) if key == "User_Goal" else float(values[key])  # type: ignore[arg-type]
        for key in REQUIRED_INPUT_FEATURES
    }
    metadata = {
        key: {
            "label": _FIELD_LABELS.get(key, key),
            "unit": _FIELD_UNITS.get(key, ""),
            "value": features[key],
            "is_imputed": key in _IMPUTABLE_FEATURES and was_missing.get(key, False),
        }
        for key in REQUIRED_INPUT_FEATURES
        if key != "User_Goal"
    }
    return features, metadata


def _impute_clinical_fields(values: dict[str, float | str | None]) -> None:
    age = _required_context(values, "Age")
    gender = _required_context(values, "Gender")
    height = _required_context(values, "Height")
    weight = _required_context(values, "Weight")
    bfm = values.get("BFM_(Body_Fat_Mass)")

    if values.get("TBW_(Total_Body_Water)") is None:
        if isinstance(bfm, float):
            values["TBW_(Total_Body_Water)"] = round((weight - bfm) * 0.732, 2)
        elif gender == 1.0:
            values["TBW_(Total_Body_Water)"] = round(
                2.447 - (0.09156 * age) + (0.1074 * height) + (0.3362 * weight),
                2,
            )
        else:
            values["TBW_(Total_Body_Water)"] = round(
                -2.097 + (0.1069 * height) + (0.2466 * weight),
                2,
            )

    if values.get("50kHz-Whole_Body_Phase_Angle") is None:
        bmi = weight / ((height / 100.0) ** 2)
        if gender == 1.0:
            values["50kHz-Whole_Body_Phase_Angle"] = round(
                8.6 - (0.044 * age) + (0.015 * bmi),
                1,
            )
        else:
            values["50kHz-Whole_Body_Phase_Angle"] = round(
                7.6 - (0.035 * age) + (0.012 * bmi),
                1,
            )

    if values.get("ECW/TBW") is None:
        values["ECW/TBW"] = round(0.370 + (age * 0.0004), 3)


def _nullable_float(value: float | int | str | None, key: str) -> float | None:
    if value is None:
        return None
    if isinstance(value, str):
        cleaned = value.strip().replace(",", "")
        if not cleaned:
            return None
        if key == "Gender":
            lowered = cleaned.lower()
            if lowered in {"male", "m"}:
                return 1.0
            if lowered in {"female", "f"}:
                return 0.0
        value = cleaned
    parsed = float(value)
    if key == "Gender" and parsed not in {0.0, 1.0}:
        raise ValueError("Gender must be 0 for female or 1 for male.")
    return parsed


def _required_context(values: dict[str, float | str | None], key: str) -> float:
    value = values.get(key)
    if not isinstance(value, float):
        raise ValueError(f"{key} is required for clinical imputation.")
    return value


class GeneratePlanRequest(BaseModel):
    """Full InBody scan data + user preferences required for plan generation."""
    model_config = ConfigDict(populate_by_name=True)

    # ── InBody biometrics (aliased to match existing InBodyPredictionRequest) ──
    age:    float = Field(alias="Age",    gt=0, le=120)
    gender: float | str = Field(alias="Gender")
    height: float = Field(alias="Height", gt=0)
    weight: float = Field(alias="Weight", gt=0)
    smm:    float = Field(alias="SMM_(Skeletal_Muscle_Mass)", gt=0)
    bmr:    float = Field(alias="BMR_(Basal_Metabolic_Rate)", gt=0)
    ffm_of_trunk:  float = Field(alias="FFM_of_Trunk",          gt=0)
    tbw:           float = Field(alias="TBW_(Total_Body_Water)", ge=0)
    ecw_tbw:       float = Field(alias="ECW/TBW",               ge=0)
    phase_angle:   float = Field(alias="50kHz-Whole_Body_Phase_Angle", ge=0)
    body_fat_mass: float = Field(alias="BFM_(Body_Fat_Mass)",   ge=0)
    percent_body_fat: float = Field(alias="PBF_(Percent_Body_Fat)", ge=0)
    user_goal: str  = Field(alias="User_Goal")

    # ── User preferences ─────────────────────────────────────────────────────
    diet_type: Literal["Vegan", "Vegetarian", "Omnivore"] = Field(
        default="Omnivore",
        description="User's dietary preference.",
    )
    preferred_days: int = Field(
        default=4,
        ge=1,
        le=7,
        description="Workout days per week (1-7).",
    )
    plan_seed: int | None = Field(
        default=None,
        description="Deterministic seed for meal/exercise selection.",
    )
    scan_id: str | None = Field(
        default=None,
        description="Confirmed scan ID for progress delta context.",
    )
    user_id: str = Field(default="local-user", description="User ID to store the generated plan.")

    @field_validator("gender")
    @classmethod
    def normalise_gender(cls, value: float | str) -> float:
        if isinstance(value, str):
            v = value.strip().lower()
            if v in {"male", "m", "1"}:
                return 1.0
            if v in {"female", "f", "0"}:
                return 0.0
            raise ValueError("Gender must be 0/1 or 'male'/'female'.")
        return float(value)

    def to_ml_features(self) -> dict[str, float | str]:
        """Build the feature dict expected by PredictionService."""
        return {
            "User_Goal":                    self.user_goal,
            "Age":                          float(self.age),
            "Gender":                       float(self.gender),
            "Height":                       float(self.height),
            "Weight":                       float(self.weight),
            "SMM_(Skeletal_Muscle_Mass)":   float(self.smm),
            "BMR_(Basal_Metabolic_Rate)":   float(self.bmr),
            "FFM_of_Trunk":                 float(self.ffm_of_trunk),
            "TBW_(Total_Body_Water)":        float(self.tbw),
            "ECW/TBW":                      float(self.ecw_tbw),
            "50kHz-Whole_Body_Phase_Angle": float(self.phase_angle),
            "BFM_(Body_Fat_Mass)":          float(self.body_fat_mass),
            "PBF_(Percent_Body_Fat)":        float(self.percent_body_fat),
        }


@app.post("/api/v1/generate-plan")
def generate_plan(
    payload: GeneratePlanRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    """Generate a personalised workout + nutrition plan.

    Pipeline:
      1. ML Engine       → classify the user's Focus Zone (1 of 4 classes).
      2. Math Engine     → deterministic calorie / macro / intensity calculation.
      3. Matching Engine → query CSV datasets and assemble the final plan.

    Returns a fully structured JSON plan ready for the Flutter frontend.
    """
    try:
        # ── 1. ML Inference Engine ───────────────────────────────────────────
        if not prediction_service.ready:
            raise HTTPException(
                status_code=503,
                detail="ML model is not loaded yet. Please try again shortly.",
            )

        ml_features = payload.to_ml_features()
        focus_zone, ml_confidence, raw_persona = predict_focus_zone(
            service=prediction_service,
            features=ml_features,
        )

        # Progress delta vs previous confirmed scan
        previous_features: dict[str, Any] | None = None
        history = scan_storage.list_history(user_id=user_id, limit=2)
        if len(history) > 1:
            previous_features = history[1].get("features")
        scan_delta = compute_delta(ml_features, previous_features)
        delta_adj = caloric_modifier(scan_delta)

        plan_seed = payload.plan_seed if payload.plan_seed is not None else abs(hash(user_id)) % 100_000

        # ── 2. Math Engine ───────────────────────────────────────────────────
        math_result = math_engine.calculate(
            age=float(payload.age),
            gender=float(payload.gender),
            weight_kg=float(payload.weight),
            height_cm=float(payload.height),
            smm_kg=float(payload.smm),
            ecw_tbw=float(payload.ecw_tbw),
            phase_angle=float(payload.phase_angle),
            goal=payload.user_goal,
            preferred_days=int(payload.preferred_days),
            extra_caloric_adjustment=delta_adj,
        )

        # ── 3. Matching Engine ───────────────────────────────────────────────
        plan = matching_engine.generate_plan(
            math_result=math_result,
            focus_zone=focus_zone,
            ml_confidence=ml_confidence,
            diet_type=payload.diet_type,
            plan_seed=plan_seed,
        )

        # ── Serialise dataclasses to plain dicts for JSON ────────────────────
        def serialise(obj):
            """Recursively convert dataclasses (including nested) to dicts."""
            if hasattr(obj, "__dataclass_fields__"):
                return {k: serialise(v) for k, v in asdict(obj).items()}
            if isinstance(obj, list):
                return [serialise(i) for i in obj]
            return obj

        response: dict[str, Any] = {
            "status": "success",
            "persona": raw_persona,
            "focus_zone": plan.focus_zone,
            "ml_confidence_pct": plan.ml_confidence_pct,
            "plan_seed": plan_seed,
            "scan_id": payload.scan_id,
            "scan_delta": {
                "has_previous": scan_delta.has_previous,
                "weight_delta_kg": scan_delta.weight_delta_kg,
                "pbf_delta_pp": scan_delta.pbf_delta_pp,
                "smm_delta_kg": scan_delta.smm_delta_kg,
                "tbw_delta_l": scan_delta.tbw_delta_l,
                "weeks_between": scan_delta.weeks_between,
            },
            "recovery_adjustments": {
                "caloric_modifier_pct": round(delta_adj * 100, 2),
            },
            "intensity_multiplier": plan.intensity_multiplier,
            "intensity_reason": plan.intensity_reason,
            "nutrition": {
                "target_calories_kcal": plan.target_calories_kcal,
                "macros": {
                    "protein_g":   plan.macros_protein_g,
                    "carbs_g":     plan.macros_carbs_g,
                    "fat_g":       plan.macros_fat_g,
                    "protein_pct": plan.macros_protein_pct,
                    "carbs_pct":   plan.macros_carbs_pct,
                    "fat_pct":     plan.macros_fat_pct,
                },
                "daily_meals": [asdict(m) for m in plan.daily_meals],
            },
            "training": {
                "preferred_days": plan.preferred_days,
                "workout_split": [
                    {
                        "day_number":  d.day_number,
                        "day_label":   d.day_label,
                        "focus_zone":  d.focus_zone,
                        "note":        d.note,
                        "exercises": [asdict(e) for e in d.exercises],
                    }
                    for d in plan.workout_split
                ],
            },
            "warnings": plan.warnings,
        }

        # Persist plan so dashboard / workout / nutrition screens can retrieve it
        try:
            user_storage.save_plan(user_id=user_id, plan=response)
        except Exception:
            logger.warning("Failed to persist plan for user %s (non-fatal)", user_id)

        return response

    except HTTPException:
        raise
    except (ValueError, ValidationError) as exc:
        logger.warning("Invalid generate-plan input: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        logger.error("Dataset missing: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("generate-plan failed")
        raise HTTPException(
            status_code=500, detail="Unable to generate plan."
        ) from exc


# ═══════════════════════════════════════════════════════════════════════════════
# Authentication — /auth/register  /auth/login
# ═══════════════════════════════════════════════════════════════════════════════

import time
from collections import defaultdict

# In-memory rate-limit buckets: {ip: [timestamp, ...]}
_auth_attempts: dict[str, list[float]] = defaultdict(list)
_RATE_WINDOW = 60.0   # seconds
_LOGIN_LIMIT = 10     # max login attempts per IP per minute
_REGISTER_LIMIT = 5   # max register attempts per IP per minute


def _check_rate_limit(request: Request, limit: int) -> None:
    ip = request.client.host if request.client else "unknown"
    now = time.monotonic()
    bucket = _auth_attempts[ip]
    # Drop timestamps outside the window
    _auth_attempts[ip] = [t for t in bucket if now - t < _RATE_WINDOW]
    if len(_auth_attempts[ip]) >= limit:
        raise HTTPException(
            status_code=429,
            detail="Too many attempts. Please wait a minute before trying again.",
        )
    _auth_attempts[ip].append(now)


class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str = ""


class LoginRequest(BaseModel):
    email: str
    password: str


@app.post("/auth/register")
def register(payload: RegisterRequest, request: Request) -> dict[str, object]:
    _check_rate_limit(request, _REGISTER_LIMIT)
    if len(payload.password) < 8:
        raise HTTPException(status_code=422, detail="Password must be at least 8 characters.")
    result = user_storage.register_user(payload.email, payload.password, payload.name)
    if result is None:
        raise HTTPException(status_code=409, detail="Email is already registered.")
    access_token = create_access_token(result["user_id"])
    return {"status": "success", "access_token": access_token, **result}


@app.post("/auth/login")
def login(payload: LoginRequest, request: Request) -> dict[str, object]:
    _check_rate_limit(request, _LOGIN_LIMIT)
    result = user_storage.login_user(payload.email, payload.password)
    if result is None:
        raise HTTPException(status_code=401, detail="Invalid email or password.")
    access_token = create_access_token(result["user_id"])
    return {"status": "success", "access_token": access_token, **result}


class SocialLoginRequest(BaseModel):
    email: str
    name: str = ""
    provider: str  # "google" | "apple"


@app.post("/auth/social-login")
def social_login(payload: SocialLoginRequest) -> dict[str, object]:
    if not payload.email or "@" not in payload.email:
        raise HTTPException(status_code=422, detail="Valid email is required.")
    result = user_storage.social_login_or_create(
        email=payload.email,
        name=payload.name,
        provider=payload.provider,
    )
    access_token = create_access_token(result["user_id"])
    return {"status": "success", "access_token": access_token, **result}


# ═══════════════════════════════════════════════════════════════════════════════
# User Profile & Preferences — /users/*
# ═══════════════════════════════════════════════════════════════════════════════

class SaveProfileRequest(BaseModel):
    user_id: str = "local-user"
    age: float | None = None
    gender: str | None = None
    height: float | None = None
    weight: float | None = None
    target_weight: float | None = None
    goal: str | None = None


class SavePreferencesRequest(BaseModel):
    user_id: str = "local-user"
    diet_type: str = "Omnivore"
    preferred_days: int = Field(default=4, ge=1, le=7)
    hydration_enabled: bool = True
    sleep_enabled: bool = False
    recovery_enabled: bool = False


@app.post("/users/profile")
def save_profile(
    payload: SaveProfileRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    user_storage.save_profile(
        user_id, payload.age, payload.gender,
        payload.height, payload.weight, payload.target_weight, payload.goal,
    )
    return {"status": "success"}


@app.get("/users/profile")
def get_profile(user_id: str = Depends(get_current_user)) -> dict[str, object]:
    profile = user_storage.get_profile(user_id)
    return {"status": "success", "profile": profile}


@app.post("/users/preferences")
def save_preferences(
    payload: SavePreferencesRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    user_storage.save_preferences(
        user_id, payload.diet_type, payload.preferred_days,
        payload.hydration_enabled, payload.sleep_enabled, payload.recovery_enabled,
    )
    return {"status": "success"}


@app.get("/users/preferences")
def get_preferences(user_id: str = Depends(get_current_user)) -> dict[str, object]:
    prefs = user_storage.get_preferences(user_id)
    return {"status": "success", "preferences": prefs}


# ═══════════════════════════════════════════════════════════════════════════════
# Plan retrieval & activity logs
# ═══════════════════════════════════════════════════════════════════════════════

class WorkoutLogRequest(BaseModel):
    user_id: str = "local-user"
    plan_id: str | None = None
    day_number: int
    rpe: int = Field(default=5, ge=1, le=10)


class MealLogRequest(BaseModel):
    user_id: str = "local-user"
    plan_id: str | None = None
    slot_name: str


@app.get("/users/plan")
def get_plan(user_id: str = Depends(get_current_user)) -> dict[str, object]:
    plan = user_storage.get_latest_plan(user_id)
    if plan is None:
        raise HTTPException(
            status_code=404,
            detail="No plan found. Complete an InBody scan first.",
        )
    return {"status": "success", "plan": plan}


@app.post("/users/plan/workout-log")
def log_workout(
    payload: WorkoutLogRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    log_id = user_storage.log_workout(
        user_id, payload.plan_id, payload.day_number, payload.rpe
    )
    return {"status": "success", "log_id": log_id}


@app.post("/users/plan/meal-log")
def log_meal(
    payload: MealLogRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    log_id = user_storage.log_meal(user_id, payload.plan_id, payload.slot_name)
    return {"status": "success", "log_id": log_id}


# ═══════════════════════════════════════════════════════════════════════════════
# Hydration
# ═══════════════════════════════════════════════════════════════════════════════

class HydrationLogRequest(BaseModel):
    cups: int = Field(default=1, ge=1, le=20)


@app.post("/users/log-hydration")
def log_hydration(
    payload: HydrationLogRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    log_id = user_storage.log_hydration(user_id, payload.cups)
    return {
        "status": "success",
        "log_id": log_id,
        "cups": payload.cups,
    }


@app.get("/users/hydration")
def get_hydration(user_id: str = Depends(get_current_user)) -> dict[str, object]:
    cups = user_storage.get_today_hydration_cups(user_id)
    return {"status": "success", "cups": cups, "target": 8}


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/users/dashboard")
def get_dashboard(user_id: str = Depends(get_current_user)) -> dict[str, object]:
    plan = user_storage.get_latest_plan(user_id)
    name = user_storage.get_user_name(user_id) or "there"

    # Calories
    target_calories = 2000.0
    if plan:
        target_calories = float(
            plan.get("nutrition", {}).get("target_calories_kcal", 2000.0)
        )

    today_meal_slots = user_storage.get_today_meal_logs(user_id)
    calories_consumed = 0.0
    if plan and today_meal_slots:
        daily_meals = plan.get("nutrition", {}).get("daily_meals", [])
        slot_cal_map = {m["slot_name"]: float(m.get("calories_per_serving", 0)) for m in daily_meals}
        calories_consumed = sum(slot_cal_map.get(s, 0.0) for s in today_meal_slots)

    # Streak
    streak = user_storage.get_streak(user_id)

    # Recovery insight
    intensity_reason = "Biomarkers within normal range — full intensity cleared."
    if plan:
        intensity_reason = str(plan.get("intensity_reason", intensity_reason))

    # Today's workout (first un-completed day)
    today_workout_label = "Rest Day"
    today_workout_logs = user_storage.get_today_workout_logs(user_id)
    if plan:
        workout_split = plan.get("training", {}).get("workout_split", [])
        completed_days = {log["day_number"] for log in today_workout_logs}
        next_day = next((d for d in workout_split if d["day_number"] not in completed_days), None)
        if next_day:
            today_workout_label = next_day.get("day_label", "Workout")

    # Next meal slot
    next_meal = "All meals logged"
    if plan:
        daily_meals = plan.get("nutrition", {}).get("daily_meals", [])
        logged_slots = set(today_meal_slots)
        next_slot = next((m for m in daily_meals if m["slot_name"] not in logged_slots), None)
        if next_slot:
            next_meal = next_slot["slot_name"].replace("_", " ").title()

    hydration_cups = user_storage.get_today_hydration_cups(user_id)

    return {
        "status": "success",
        "dashboard": {
            "user_name": name,
            "calories_target": target_calories,
            "calories_consumed": calories_consumed,
            "hydration_cups": hydration_cups,
            "hydration_target": 8,
            "streak": streak,
            "recovery_insight": intensity_reason,
            "today_workout_label": today_workout_label,
            "next_meal": next_meal,
        },
    }


# ═══════════════════════════════════════════════════════════════════════════════
# Progress
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/users/progress")
def get_progress(user_id: str = Depends(get_current_user)) -> dict[str, object]:
    progress = user_storage.get_progress(user_id)
    return {"status": "success", "progress": progress}


# ═══════════════════════════════════════════════════════════════════════════════
# Daily progress (Feature 5)
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/users/daily-progress")
def get_daily_progress(
    date: str = Query(..., description="YYYY-MM-DD"),
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    try:
        progress = user_storage.get_daily_progress(user_id, date)
        return {"status": "success", **progress}
    except Exception as exc:
        logger.exception("daily-progress failed")
        raise HTTPException(status_code=500, detail="Unable to fetch daily progress.") from exc


# ═══════════════════════════════════════════════════════════════════════════════
# Extended workout / meal log endpoints (Feature 5)
# ═══════════════════════════════════════════════════════════════════════════════

class ExtendedWorkoutLogRequest(BaseModel):
    user_id: str = "local-user"
    plan_id: str | None = None
    day_number: int
    rpe: int = Field(default=5, ge=1, le=10)
    exercises_completed: list[str] = Field(default_factory=list)
    duration_minutes: int = Field(default=0, ge=0)


class ExtendedMealLogRequest(BaseModel):
    user_id: str = "local-user"
    plan_id: str | None = None
    slot_name: str
    calories_consumed: float = Field(default=0.0, ge=0)


@app.post("/users/log-workout")
def log_workout_extended(
    payload: ExtendedWorkoutLogRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    log_id = user_storage.log_workout(
        user_id,
        payload.plan_id,
        payload.day_number,
        payload.rpe,
        payload.exercises_completed,
        payload.duration_minutes,
    )
    newly_earned = user_storage.check_and_award_achievements(user_id)
    return {"status": "success", "log_id": log_id, "new_achievements": newly_earned}


@app.post("/users/log-meal")
def log_meal_extended(
    payload: ExtendedMealLogRequest,
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    log_id = user_storage.log_meal(
        user_id,
        payload.plan_id,
        payload.slot_name,
        payload.calories_consumed,
    )
    return {"status": "success", "log_id": log_id}


# ═══════════════════════════════════════════════════════════════════════════════
# Achievements (Feature 3)
# ═══════════════════════════════════════════════════════════════════════════════

@app.post("/achievements/check")
def check_achievements(
    user_id: str = Depends(get_current_user),
) -> dict[str, object]:
    try:
        newly_earned = user_storage.check_and_award_achievements(user_id)
        return {"status": "success", "new_achievements": newly_earned}
    except Exception as exc:
        logger.exception("achievement check failed")
        raise HTTPException(status_code=500, detail="Unable to check achievements.") from exc


@app.get("/achievements")
def get_achievements(user_id: str = Depends(get_current_user)) -> dict[str, object]:
    try:
        achievements = user_storage.get_achievements(user_id)
        return {"status": "success", "achievements": achievements}
    except Exception as exc:
        logger.exception("get achievements failed")
        raise HTTPException(status_code=500, detail="Unable to fetch achievements.") from exc
