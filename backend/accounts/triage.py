# accounts/triage.py
from dataclasses import dataclass
import logging
from typing import Any, Dict, List, Optional

# Import the model predictor (the LoRA adapter inference wrapper)
from .triage_model import predict_symptoms_score
logger = logging.getLogger("django")


@dataclass(frozen=True)
class TriageResult:
    score: int
    confidence: int
    missing_fields: List[str]
    score_version: str = "triage_v2"


def compute_vitals_score(triage_data: Dict[str, Any], model_score: Any) -> int:
    """Compute rule-based score using vitals only (temperature, BP, HR)."""
    temperature_c = triage_data.get("temperature_c")
    bp_systolic = triage_data.get("bp_systolic")
    bp_diastolic = triage_data.get("bp_diastolic")
    heart_rate = triage_data.get("heart_rate")

    # Start baseline safely
    score = float(model_score) if isinstance(model_score, (int, float)) else 0.0

    # Temperature
    try:
        if temperature_c not in (None, ""):
            t = float(temperature_c)  # works for Decimal too
            if t >= 38.0:
                score += 2.0
            if t >= 39.5:
                score += 1.0
    except (TypeError, ValueError):
        pass

    # Heart rate
    try:
        if heart_rate not in (None, ""):
            hr = int(heart_rate)
            if hr >= 110:
                score += 2.0
            if hr >= 130:
                score += 1.0
    except (TypeError, ValueError):
        pass

    # Blood pressure (only if both provided)
    try:
        if bp_systolic not in (None, "") and bp_diastolic not in (None, ""):
            sys = int(bp_systolic)
            dia = int(bp_diastolic)
            if sys >= 170 or dia >= 110:
                score += 2.0
            if sys <= 90 or dia <= 60:
                score += 1.0
    except (TypeError, ValueError):
        pass

    return max(1, min(10, int(round(score))))


def _is_valid_model_score(model_score: Any) -> bool:
    return isinstance(model_score, int) and 1 <= model_score <= 10


def compute_triage(
    triage_data: Dict[str, Any],
    model_score: Optional[int] = None,
) -> TriageResult:
    """
    Your original combine logic:
    - If symptoms_text exists and model_score is valid: final = max(model, vitals)
    - If symptoms_text exists but model_score missing/invalid: final = max(vitals, safe_floor)
    - If symptoms_text missing: final = vitals only
    """
    symptoms_text: Optional[str] = (triage_data.get("symptoms_text") or "").strip() or None
    temperature_c = triage_data.get("temperature_c")
    bp_systolic = triage_data.get("bp_systolic")
    bp_diastolic = triage_data.get("bp_diastolic")
    heart_rate = triage_data.get("heart_rate")

    missing: List[str] = []
    if not symptoms_text:
        missing.append("symptoms_text")
    if temperature_c in (None, ""):
        missing.append("temperature_c")
    if bp_systolic in (None, ""):
        missing.append("bp_systolic")
    if bp_diastolic in (None, ""):
        missing.append("bp_diastolic")
    if heart_rate in (None, ""):
        missing.append("heart_rate")

    vitals_score = compute_vitals_score(triage_data, model_score)
    valid_model_score = model_score if _is_valid_model_score(model_score) else None

    missing_vitals = sum(
        k in missing for k in ["temperature_c", "bp_systolic", "bp_diastolic", "heart_rate"]
    )

    if symptoms_text:
        if valid_model_score is not None:
            final_score = max(valid_model_score, vitals_score)
            confidence = 100 - 10 * missing_vitals
            if vitals_score >= 7 and missing_vitals == 0:
                confidence = 100
        else:
            SAFE_FLOOR_WITH_SYMPTOMS = 4
            final_score = max(vitals_score, SAFE_FLOOR_WITH_SYMPTOMS)
            confidence = 40 - 5 * missing_vitals
    else:
        final_score = vitals_score
        total_fields = 5
        provided = total_fields - len(missing)
        confidence = int(round((provided / total_fields) * 100))

    final_score = max(1, min(10, int(final_score)))
    confidence = max(0, min(100, int(confidence)))

    return TriageResult(
        score=final_score,
        confidence=confidence,
        missing_fields=missing,
        score_version="triage_v1",
    )

import inspect

def compute_triage_score(triage_data: Dict[str, Any]) -> TriageResult:
    """
    This is what your serializer calls.
    It runs the model if symptoms_text exists, then calls compute_triage().
    """
    symptoms_text = (triage_data.get("symptoms_text") or "").strip()

    model_score: int = 0
    model_conf: int = 0
    score_version = "triage_v1"

    if symptoms_text:
        model_score, model_conf = predict_symptoms_score(symptoms_text)
        if model_score > 0:
            score_version = "triage_v2"
        else:
            score_version = "triage_v1"

    result = compute_triage(triage_data, model_score=model_score)

    if model_score > 0:
        result = TriageResult(
            score=result.score,
            confidence=min(result.confidence, model_conf),
            missing_fields=result.missing_fields,
            score_version=score_version,
        )
    else:
        result = TriageResult(
            score=result.score,
            confidence=result.confidence,
            missing_fields=result.missing_fields,
            score_version=score_version,
        )

    return result