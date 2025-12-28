A) Booking — Patient

A1. Patient يحجز ضمن الدوام وبدون تضارب

Endpoint: POST /api/appointments/

Expected:

201 Created

status = "pending"

A2. Patient يحجز خارج دوام الطبيب

Expected:

400 Bad Request

A3. Patient يحجز بتداخل (Overlap)

التداخل يُحسب وفق المبدأ: [start, end)

Expected:

400 Bad Request

A4. Patient يحجز موعدًا من نوع requires_approved_files=True بدون ملفات approved

Expected:

400 Bad Request

رسالة موحّدة:

Follow-up booking is blocked until required files are approved.

B) Authorization & Roles

B1. Doctor يحاول إنشاء موعد (Booking)

بدون توكن:

401 Unauthorized

مع توكن Doctor:

403 Forbidden

الحجز مسموح للمريض فقط (IsPatient).

C) no_show — Doctor

C1. Doctor يعيّن no_show لموعد لا يخصّه

Endpoint: POST /api/appointments/<id>/mark-no-show/

Expected:

404 Not Found

يتم إرجاع 404 بدل 403 لتجنّب كشف وجود موعد لا يخص الطبيب.

C2. Doctor يعيّن no_show لموعد cancelled

Expected:

400 Bad Request

رسالة واضحة تفيد بعدم السماح بتغيير الحالة.

ملاحظة: لا يوجد حاليًا مفهوم “منتهي حسب الزمن”.
الحالات المعتمدة فقط هي status.

D) Time & Formatting

date_time:

يُخزَّن كـ timezone-aware.

يُعاد في الـ response بصيغة ISO واضحة (مثال: 2026-01-06T10:30:00Z).

E) Appointment Status Semantics

الحالات التي تحجز وقتًا:

pending

confirmed

الحالات التي لا تحجز وقتًا:

cancelled

no_show

منطق التداخل يعتمد فقط على:
status IN ("pending", "confirmed")
f) PASSED (Manual Verification)
- When requires_approved_files=True and no approved files exist → booking returns 400 (blocked).
- After uploading a file and doctor approval (and ensuring no other open orders are missing approved files) → booking returns 201 with status=pending.
