import logging
import os
import time
from typing import Any, Dict, Tuple

import requests

TRIAGE_MODEL_URL = os.getenv("TRIAGE_MODEL_URL", "").rstrip("/")
TRIAGE_MODEL_API_KEY = os.getenv("TRIAGE_MODEL_API_KEY", "")
TRIAGE_MODEL_TIMEOUT_S = float(os.getenv("TRIAGE_MODEL_TIMEOUT_S", "20.0"))

logger = logging.getLogger("django")


def predict_symptoms_score(symptoms_text: str) -> Tuple[int, int]:
    """
    POST symptoms_text -> returns (score, confidence)
    On ANY failure: returns (0, 0) so the caller can safely fall back.
    Expected response JSON: {"score": 7, "confidence": 55}
    """
    if not TRIAGE_MODEL_URL:
        logger.warning("TRIAGE_MODEL_URL is not set. Falling back to (0, 0).")
        return 0, 0

    payload: Dict[str, Any] = {"symptoms_text": symptoms_text}
    headers = {"Content-Type": "application/json"}
    if TRIAGE_MODEL_API_KEY:
        headers["Authorization"] = f"Bearer {TRIAGE_MODEL_API_KEY}"

    url = f"{TRIAGE_MODEL_URL}/predict"

    try:
        t0 = time.time()
        resp = requests.post(url, json=payload, headers=headers, timeout=TRIAGE_MODEL_TIMEOUT_S)
        elapsed_ms = int((time.time() - t0) * 1000)

        # Helpful production logs
        logger.info("Model request done status=%s elapsed_ms=%s url=%s", resp.status_code, elapsed_ms, url)

        resp.raise_for_status()
        data = resp.json()

        score = data.get("score")
        confidence = data.get("confidence")

        if not isinstance(score, int) or not (1 <= score <= 10):
            logger.warning("Invalid model score %r. Falling back to (0, 0). Raw=%r", score, data)
            return 0, 0

        if not isinstance(confidence, int) or not (0 <= confidence <= 100):
            logger.warning("Invalid model confidence %r. Falling back to (0, 0). Raw=%r", confidence, data)
            return 0, 0

        return score, confidence

    except (requests.Timeout, requests.RequestException, ValueError) as e:
        # Timeout / network / non-2xx / JSON decode -> fallback
        logger.exception("Model call failed, falling back to (0, 0). url=%s err=%s", url, e)
        return 0, 0
