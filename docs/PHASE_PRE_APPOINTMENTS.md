# Phase Pre-Appointments (phase-pre-appointments)

## الهدف
تنفيذ تعديلات صغيرة وضرورية قبل البدء بمرحلة المواعيد، بدون إدخال منطق المواعيد نفسه.

## خارج النطاق
- إنشاء/حجز/جدولة مواعيد
- إشعارات/تذكيرات
- ذكاء/تحليلات
- PIN (يبقى غير مفعّل)

## Backlog (مُعتمد)
1) DoctorSpecificVisitType
- السماح للطبيب بإضافة نوع زيارة خاص به (مثل Root Canal 30min)
- AppointmentType يبقى مركزي (Admin فقط)
- التنفيذ: Backend + UI minimal في شاشة إعدادات الطبيب

2) تبويب “الملف الصحي” داخل الإضبارة
- عرض حقول: BMI, health_notes, gender, blood_type, chronic_diseases
- للطبيب: عرض فقط
- للمريض: عرض فقط داخل الإضبارة، والتعديل يبقى من تبويب الحساب

3) إصلاح Tab Flicker في الإضبارة
- عند الضغط على prescripts/adherence يظهر تبويب 0 لحظة ثم يستقر
- الهدف: انتقال سلس بدون إعادة تحميل ظاهرية

4) تحسين شاشة Adherence (UX + Layout)
- إضافة سياق للوصفة داخل بطاقة تفاصيل الدواء
- حل RenderFlex overflow (Scrollable layout)
- إضافة “إلغاء الاختيار/طي التفاصيل”
- ملاحظة: منطق عدد الحبات/الالتزام للأبد مؤجل، لكن نراجع سلوك تواريخ البدء/الانتهاء (تحذير أو منع بسيط حسب القرار)

## Definition of Done
- كل بند أعلاه مُنفذ بــ commit مستقل وواضح
- لا تغييرات خارج النطاق
- الالتزام بـ DECISIONS و CODE_REVIEW_CHECKLIST
- الشجرة clean + push للفرع phase-pre-appointments
