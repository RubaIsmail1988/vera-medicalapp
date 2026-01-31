# backend/clinical/advice/engine_base.py
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import List

from .contracts import AdviceCard


class AdviceEngine(ABC):
    @abstractmethod
    def generate(self, patient_details) -> List[AdviceCard]:
        raise NotImplementedError
