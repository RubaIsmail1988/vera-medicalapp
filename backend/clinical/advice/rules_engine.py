# backend/clinical/advice/rules_engine.py
from __future__ import annotations

from datetime import date
from typing import List, Optional

from .contracts import AdviceCard
from .engine_base import AdviceEngine
from .templates import TEMPLATES


def _age_years(dob: Optional[date]) -> Optional[int]:
    if not dob:
        return None
    today = date.today()
    years = today.year - dob.year
    if (today.month, today.day) < (dob.month, dob.day):
        years -= 1
    return years


def _bmi_category(bmi: Optional[float]) -> Optional[str]:
    if bmi is None:
        return None
    if bmi < 18.5:
        return "underweight"
    if bmi < 25:
        return "normal"
    if bmi < 30:
        return "overweight"
    return "obese"


class RuleBasedAdviceEngine(AdviceEngine):
    ENGINE_NAME = "rules"

    def generate(self, patient_details) -> List[AdviceCard]:
        cards: List[AdviceCard] = []

        age = _age_years(getattr(patient_details, "date_of_birth", None))

        # --- BMI advice
        bmi = getattr(patient_details, "bmi", None)
        cat = _bmi_category(bmi)

        if cat is None:
            t = TEMPLATES["bmi_missing"]
            cards.append(self._card_from_template(t))
        else:
            if cat == "underweight":
                t = TEMPLATES["bmi_underweight"]
                cards.append(self._card_from_template(t, meta={"bmi": bmi}))
            elif cat == "normal":
                t = TEMPLATES["bmi_normal"]
                cards.append(self._card_from_template(t, meta={"bmi": bmi}))
            elif cat == "overweight":
                t = TEMPLATES["bmi_overweight"]
                cards.append(self._card_from_template(t, meta={"bmi": bmi}))
            elif cat == "obese":
                t = TEMPLATES["bmi_obese"]
                cards.append(self._card_from_template(t, meta={"bmi": bmi}))

        # --- Smoking advice
        smoking_status = getattr(patient_details, "smoking_status", None)
        if smoking_status == "current":
            t = TEMPLATES["smoking_current"]
            cpd = getattr(patient_details, "cigarettes_per_day", None)

            msg = t.message
            if cpd:
                msg += f" أنت تسجل تقريبًا {cpd} سيجارة/يوم—ابدأ بتقليل تدريجي مع خطة واضحة."

            cards.append(
                AdviceCard(
                    key=t.key,
                    title=t.title,
                    message=msg,
                    severity=t.severity,
                    score=t.score,
                    engine=self.ENGINE_NAME,
                    cta_label=t.cta_label,
                    cta_route=t.cta_route,
                    meta={"cigarettes_per_day": cpd},
                )
            )

        elif smoking_status == "former":
            t = TEMPLATES["smoking_former"]
            cards.append(self._card_from_template(t))

        # --- Alcohol advice
        alcohol_use = getattr(patient_details, "alcohol_use", None)
        if alcohol_use == "regular":
            t = TEMPLATES["alcohol_regular"]
            cards.append(self._card_from_template(t))

        # --- Activity advice
        activity_level = getattr(patient_details, "activity_level", None)
        if activity_level == "low":
            t = TEMPLATES["activity_low"]
            cards.append(self._card_from_template(t))

        # --- Chronic conditions advice
        if getattr(patient_details, "has_hypertension", False):
            t = TEMPLATES["hypertension"]
            sys = getattr(patient_details, "last_bp_systolic", None)
            dia = getattr(patient_details, "last_bp_diastolic", None)

            msg = t.message
            if sys and dia:
                msg = f"{msg} آخر قراءة مسجلة: {sys}/{dia}."

            cards.append(
                AdviceCard(
                    key=t.key,
                    title=t.title,
                    message=msg,
                    severity=t.severity,
                    score=t.score,
                    engine=self.ENGINE_NAME,
                    cta_label=t.cta_label,
                    cta_route=t.cta_route,
                    meta={"bp": {"systolic": sys, "diastolic": dia}},
                )
            )

        if getattr(patient_details, "has_diabetes", False):
            t = TEMPLATES["diabetes"]
            hba1c = getattr(patient_details, "last_hba1c", None)

            msg = t.message
            if hba1c is not None:
                msg += f" HbA1c آخر قيمة: {hba1c}."

            cards.append(
                AdviceCard(
                    key=t.key,
                    title=t.title,
                    message=msg,
                    severity=t.severity,
                    score=t.score,
                    engine=self.ENGINE_NAME,
                    cta_label=t.cta_label,
                    cta_route=t.cta_route,
                    meta={"hba1c": hba1c},
                )
            )

        # --- Pregnancy advice
        if getattr(patient_details, "is_pregnant", False):
            t = TEMPLATES["pregnancy"]
            cards.append(self._card_from_template(t))

        # --- Age-based nudge (soft)
        if age is not None and age >= 40:
            t = TEMPLATES["age_40_plus"]
            cards.append(self._card_from_template(t))

        # Sort highest severity first (كما كان عندك)
        cards.sort(key=lambda c: c.severity, reverse=True)
        return cards

    def _card_from_template(self, t, meta=None) -> AdviceCard:
        return AdviceCard(
            key=t.key,
            title=t.title,
            message=t.message,
            severity=t.severity,
            score=t.score,
            engine=self.ENGINE_NAME,
            cta_label=t.cta_label,
            cta_route=t.cta_route,
            meta=meta,
        )
