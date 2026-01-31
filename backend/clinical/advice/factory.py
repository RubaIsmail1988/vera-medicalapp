# backend/clinical/advice/factory.py
from __future__ import annotations

from django.conf import settings

from .ml_engine import MLAdviceEngine
from .rules_engine import RuleBasedAdviceEngine


def get_advice_engine():
    engine = getattr(settings, "ADVICE_ENGINE", "rules").strip().lower()
    if engine == "ml":
        version = getattr(settings, "ADVICE_MODEL_VERSION", "v0")
        return MLAdviceEngine(model_version=version)
    return RuleBasedAdviceEngine()
