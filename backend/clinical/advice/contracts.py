# backend/clinical/advice/contracts.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass(frozen=True)
class AdviceCard:
    key: str
    title: str
    message: str
    severity: int             # 1..10
    score: float              # 0..1 (حتى rules)
    engine: str               # "rules" | "ml"
    model_version: Optional[str] = None

    cta_label: Optional[str] = None
    cta_route: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "key": self.key,
            "title": self.title,
            "message": self.message,
            "severity": int(self.severity),
            "score": float(self.score),
            "engine": self.engine,
            "model_version": self.model_version,
            "cta_label": self.cta_label,
            "cta_route": self.cta_route,
            "meta": self.meta or {},
        }
