import logging
import os
import time
from typing import Any, Dict, Tuple

import requests

import sys
sys.stderr.write(">>> predict_symptoms_score INVOKED\n")
sys.stderr.flush()

TRIAGE_MODEL_URL = os.getenv("TRIAGE_MODEL_URL", "").rstrip("/")  # e.g. https://ml.example.com
TRIAGE_MODEL_API_KEY = os.getenv("TRIAGE_MODEL_API_KEY", "")
TRIAGE_MODEL_TIMEOUT_S = float(os.getenv("TRIAGE_MODEL_TIMEOUT_S", "20.0"))


class TriageModelError(RuntimeError):
    pass

logger = logging.getLogger("django")


def predict_symptoms_score(symptoms_text: str) -> Tuple[int, int]:
    """
    POST symptoms_text -> returns (score, confidence)
    Expected response JSON:
      {"score": 7, "confidence": 55}
    """
    if not TRIAGE_MODEL_URL:
        raise TriageModelError("TRIAGE_MODEL_URL is not set")

    payload: Dict[str, Any] = {"symptoms_text": symptoms_text}
    logger.info(payload)
    headers = {
        "Content-Type": "application/json",
    }
    # if TRIAGE_MODEL_API_KEY:
    #     headers["Authorization"] = f"Bearer {TRIAGE_MODEL_API_KEY}"

    url = f"{TRIAGE_MODEL_URL}/predict"  # adjust path to your API
    logger.info("Sending request to model URL: %s", url)
    try:
        t0 = time.time()
        resp = requests.post(url, json=payload, headers=headers, timeout=100000)
        elapsed_ms = int((time.time() - t0) * 1000)

        resp.raise_for_status()
        data = resp.json()

    except requests.Timeout as e:
        raise TriageModelError("Model request timed out") from e
    except requests.RequestException as e:
        raise TriageModelError(f"Model request failed: {e}") from e
    except ValueError as e:
        # JSON decode error
        raise TriageModelError("Model response was not valid JSON") from e
    logger.info("Model raw response: %s", data)

    score = data.get("score")
    confidence = data.get("confidence")

    if not isinstance(score, int) or not (1 <= score <= 10):
        raise TriageModelError(f"Invalid 'score' in model response: {score}")
    if not isinstance(confidence, int) or not (0 <= confidence <= 100):
        raise TriageModelError(f"Invalid 'confidence' in model response: {confidence}")

    return score, confidence
