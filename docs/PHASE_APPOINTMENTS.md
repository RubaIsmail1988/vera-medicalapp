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
----------------------------------------
Appointment Cancellation & no_show — Verification (MVP)
Cancel Appointment

Endpoint

POST /api/appointments/{id}/cancel/


Authorized roles

Patient (مالك الموعد)

Doctor (صاحب الموعد)

Admin

Rules

الموعد بحالة pending أو confirmed يمكن إلغاؤه.

الموعد بحالة cancelled:

الإلغاء idempotent (يبقى cancelled).

الموعد بحالة no_show:

لا يمكن إلغاؤه.

Expected Responses

200 → عند الإلغاء الناجح.

400 → محاولة إلغاء موعد no_show.

404 → عند محاولة الإلغاء من مستخدم لا يملك الموعد.

401 → بدون توكن.

no_show Handling

Endpoint

POST /api/appointments/{id}/mark-no-show/


Rules

مسموح للطبيب صاحب الموعد فقط.

لا يمكن تعيين no_show إلا لموعد غير ملغى.

no_show حالة تاريخية ولا تحجز وقتًا مستقبليًا.

Time Slot Reservation Rules (Confirmed)

الحالات التي تحجز الوقت:

pending

confirmed

الحالات التي لا تحجز الوقت:

cancelled

no_show

بالتالي:

يمكن الحجز في نفس الوقت بعد cancelled.

يمكن الحجز في نفس الوقت بعد no_show.

Verification Status

 PASSED (Manual Postman Tests)

Patient/Doctor cancellation works as expected.

no_show cannot be cancelled.

cancelled / no_show do not block future bookings.

Unauthorized and non-owner access handled correctly.

Future Consideration (Out of Scope — Documented)

تكرار إلغاء المريض (cancelled) سيؤثر لاحقًا على أولوية الحجز ضمن:

التحليلات

الجدولة المتقدمة

لا منطق أولوية مطبق في مرحلة MVP.