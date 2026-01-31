# backend/clinical/advice/templates.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class AdviceTemplate:
    key: str
    title: str
    message: str
    severity: int
    score: float
    cta_label: Optional[str] = None
    cta_route: Optional[str] = None


TEMPLATES: dict[str, AdviceTemplate] = {
    # BMI
    "bmi_missing": AdviceTemplate(
        key="bmi_missing",
        title="أكمل بيانات القياسات",
        message="أدخل الطول والوزن ليتم حساب مؤشر كتلة الجسم (BMI) وتظهر نصائح مناسبة.",
        severity=3,
        score=0.90,
        cta_label="تعديل البيانات الصحية",
        cta_route="/patient/profile/edit",
    ),
    "bmi_underweight": AdviceTemplate(
        key="bmi_underweight",
        title="وزن أقل من الطبيعي",
        message="قد يفيد تحسين الوجبات وزيادة البروتين والسعرات بشكل صحي. إذا كان هناك فقدان وزن غير مبرّر، راجع طبيبًا.",
        severity=5,
        score=0.70,
        cta_label="حجز موعد",
        cta_route="/patient/appointments/book",
    ),
    "bmi_normal": AdviceTemplate(
        key="bmi_normal",
        title="BMI ضمن الطبيعي",
        message="حافظ على نشاط منتظم ونمط غذائي متوازن للحفاظ على النتائج.",
        severity=2,
        score=0.55,
    ),
    "bmi_overweight": AdviceTemplate(
        key="bmi_overweight",
        title="زيادة وزن بسيطة",
        message="المشي 30 دقيقة يوميًا وتقليل السكريات قد يساعد. إذا لديك ضغط/سكر، المتابعة الدورية مهمة.",
        severity=4,
        score=0.65,
        cta_label="نصائح نمط حياة",
        cta_route="/patient/health/tips",
    ),
    "bmi_obese": AdviceTemplate(
        key="bmi_obese",
        title="سمنة (BMI مرتفع)",
        message="قد يفيد وضع خطة غذائية ونشاط تدريجي. إذا لديك أمراض مزمنة، الأفضل المتابعة مع طبيب.",
        severity=7,
        score=0.80,
        cta_label="حجز موعد",
        cta_route="/patient/appointments/book",
    ),

    # Smoking
    "smoking_current": AdviceTemplate(
        key="smoking_current",
        title="التدخين",
        message="الإقلاع عن التدخين يقلل مخاطر القلب والرئة بشكل كبير.",
        severity=6,
        score=0.85,
        cta_label="خطة الإقلاع",
        cta_route="/patient/health/quit-smoking",
    ),
    "smoking_former": AdviceTemplate(
        key="smoking_former",
        title="مدخّن سابق",
        message="استمر بالابتعاد عن التدخين—الفوائد الصحية تزداد مع الوقت.",
        severity=2,
        score=0.55,
    ),

    # Alcohol
    "alcohol_regular": AdviceTemplate(
        key="alcohol_regular",
        title="استهلاك كحول منتظم",
        message="تقليل الكحول يساعد على تحسين النوم، الضغط، وصحة الكبد. إذا لديك أعراض أو أدوية مزمنة، استشر طبيبًا.",
        severity=5,
        score=0.70,
        cta_label="نصائح",
        cta_route="/patient/health/tips",
    ),

    # Activity
    "activity_low": AdviceTemplate(
        key="activity_low",
        title="نشاط منخفض",
        message="ابدأ بخطوات بسيطة: 15–30 دقيقة مشي يوميًا 4–5 أيام بالأسبوع.",
        severity=3,
        score=0.60,
        cta_label="خطة نشاط",
        cta_route="/patient/health/activity-plan",
    ),

    # Chronic conditions
    "hypertension": AdviceTemplate(
        key="hypertension",
        title="ارتفاع ضغط",
        message="راقب ضغطك بانتظام وقلّل الملح.",
        severity=6,
        score=0.80,
        cta_label="إدخال قراءة ضغط",
        cta_route="/patient/health/bp",
    ),
    "diabetes": AdviceTemplate(
        key="diabetes",
        title="السكري",
        message="تابع السكر ونمط الأكل، وراجع طبيبك دوريًا.",
        severity=6,
        score=0.80,
        cta_label="إدخال HbA1c",
        cta_route="/patient/health/hba1c",
    ),

    # Pregnancy
    "pregnancy": AdviceTemplate(
        key="pregnancy",
        title="الحمل",
        message="يفيد متابعة منتظمة مع طبيب/ة النساء والتأكد من الفيتامينات والفحوصات الدورية.",
        severity=6,
        score=0.75,
        cta_label="حجز موعد",
        cta_route="/patient/appointments/book",
    ),

    # Age
    "age_40_plus": AdviceTemplate(
        key="age_40_plus",
        title="فحوصات دورية",
        message="بعد عمر 40، يُنصح بمتابعة الضغط والسكر والدهون بشكل دوري.",
        severity=3,
        score=0.60,
    ),
}
