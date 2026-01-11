from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass(frozen=True)
class TriageResult:
    score: int
    confidence: int
    missing_fields: List[str]
    score_version: str = "triage_v1"


def compute_triage_score(triage_data: Dict[str, Any]) -> TriageResult:
    """
    Rule-based triage scoring (non-diagnostic).
    Uses only provided fields; missing inputs reduce confidence.
    Score is clamped to 1..10.
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

    raw = 1.0

    # Symptoms: length-based heuristic to avoid medical claims
    if symptoms_text:
        if len(symptoms_text) >= 20:
            raw += 1.0
        if len(symptoms_text) >= 80:
            raw += 1.0

    # Temperature signal
    try:
        if temperature_c not in (None, ""):
            t = float(temperature_c)
            if t >= 38.0:
                raw += 2.0
            if t >= 39.5:
                raw += 1.0
    except (TypeError, ValueError):
        pass

    # Heart rate signal
    try:
        if heart_rate not in (None, ""):
            hr = int(heart_rate)
            if hr >= 110:
                raw += 2.0
            if hr >= 130:
                raw += 1.0
    except (TypeError, ValueError):
        pass

    # BP signal (only if both provided)
    try:
        if bp_systolic not in (None, "") and bp_diastolic not in (None, ""):
            sys = int(bp_systolic)
            dia = int(bp_diastolic)
            if sys >= 170 or dia >= 110:
                raw += 2.0
            if sys <= 90 or dia <= 60:
                raw += 1.0
    except (TypeError, ValueError):
        pass

    score = max(1, min(10, int(round(raw))))

    total_fields = 5
    provided = total_fields - len(missing)
    confidence = int(round((provided / total_fields) * 100))

    return TriageResult(score=score, confidence=confidence, missing_fields=missing)
