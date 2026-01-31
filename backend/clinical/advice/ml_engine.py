# backend/clinical/advice/ml_engine.py
from __future__ import annotations

from typing import List, Optional

from .contracts import AdviceCard
from .engine_base import AdviceEngine


class MLAdviceEngine(AdviceEngine):
    ENGINE_NAME = "ml"

    def __init__(self, model_version: str, model=None):
        self.model_version = model_version
        self.model = model  # لاحقًا: تحميل نموذج فعلي

    def generate(self, patient_details) -> List[AdviceCard]:
        # لاحقًا: inference يختار keys + severity + score
        # مبدئيًا نرجع قائمة فاضية أو تقدر تعمل fallback في factory
        return []
