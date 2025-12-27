1) حدود النطاق (Scope Boundaries)
ميزات مؤجلة صراحة

PIN: ملفات PIN موجودة (screens/pin) لكنها غير مربوطة بالـ flow الحالي.

المواعيد / الحجز / الجدولة: لم يبدأ تنفيذها بعد.

الإشعارات / التذكيرات: مؤجّلة لمرحلة لاحقة (مرجّح تنفيذها من جهة Flutter).

الذكاء الاصطناعي / التحليلات: خارج النطاق الحالي.

أي مرحلة أو محادثة جديدة يجب أن تحترم هذه الحدود.

2) التوجيه والتنقل (Routing) — go_router

التطبيق يعتمد على go_router كبنية تنقّل أساسية للشاشات التي لها Routes (URL).

قواعد ملزمة

يُمنع استخدام Navigator.push/pop للتنقل بين الشاشات المعرّفة كـ routes في go_router.

الاستثناءات المسموحة:

showDialog وما شابه (Dialogs).

تنقل داخلي محدود لصفحات غير معرّفة كRoutes (مثل بعض شاشات الفورم في الأدمن إن لم تكن Routes).

البنية العامة

/ → Splash

Auth

/login

/register

/waiting-activation

/forgot-password

/forgot-password/verify

/forgot-password/new

Admin (Shell + initialIndex)

/admin وما تحته

User App

كل ما يخص المستخدم يجب أن يكون تحت /app كـ children routes.

مبدأ أساسي

Refresh أو فتح رابط مباشر يجب ألا يعيد المستخدم بشكل غير متوقّع إلى Splash.

عند وجود Tabs مرتبطة بالمسارات (مثل الإضبارة) يجب الحفاظ على Tab ↔ Route Sync.

3) نظام التنبيهات الموحد (SnackBars)

يُمنع استخدام ScaffoldMessenger.of(context) مباشرة داخل الشاشات.

يجب استخدام النظام الموحد الموجود في:

mobile/lib/utils/ui_helpers.dart

المرجع الأساسي

rootScaffoldMessengerKey هو المرجع الأساسي لعرض SnackBar.

الدوال المعتمدة

showAppSnackBar(...)

showAppErrorSnackBar(...)

showAppSuccessSnackBar(...)

الهدف:

تفادي مشاكل context after await

تفادي مشاكل go_router

تفادي غياب ScaffoldMessenger في حالات bootstrap

4) Dialog التأكيد (Confirm Dialog)

العمليات الحساسة (حذف، رفض، تعطيل…) يجب أن تستخدم Dialog تأكيد موحّد:

showConfirmDialog(...) في ui_helpers.dart

5) الثيم، الثوابت، والـ Helpers

Theme مركزي: mobile/lib/theme/app_theme.dart

Constants: mobile/lib/utils/constants.dart

UI Helpers: mobile/lib/utils/ui_helpers.dart

يُمنع إنشاء أنظمة موازية أو مكررة لنفس الغرض.

6) قواعد تطوير ملزمة (Guardrails)
6.1 SnackBars

أي SnackBar يجب أن يستخدم helpers الموحّدة فقط.

6.2 context بعد await

في أي StatefulWidget:
إذا وُجد await ثم استخدام context أو setState أو تنقل، يجب التحقق:

if (!mounted) return;

6.3 go_router بدل Navigator

في الشاشات المرتبطة بالـ routes:

استخدم context.go أو context.push

(مع استثناءات القسم 2).

6.4 الألوان

يمنع withOpacity

يستخدم withValues(alpha: ...)

6.5 الأزرار أثناء التحميل

أي زر يقوم بعملية async:

يُعطّل أثناء التنفيذ

يُظهر مؤشر تحميل صغير داخل الزر بنمط موحّد

6.6 منع Rebuild Loops

عند استخدام state.extra أو queryParameters:

يُمنع تنفيذ منطق يؤدي إلى setState متكرر داخل build()

انقل الاستخراج إلى initState أو didChangeDependencies عند الحاجة

7) الإضبارة الطبية (Clinical Module)

الكيانات السريرية غير مربوطة إلزاميًا بموعد (الربط بالمواعيد مؤجّل).

لا IDs تُعرض في الواجهة.

Backend (عرض فقط)

تم إضافة حقول read-only في serializers لأغراض العرض فقط مثل:

doctor_display_name

patient_display_name

وفي الالتزام الدوائي: medicine_name, dosage, frequency

بدون تغييرات على:

الصلاحيات

الـ endpoints

قاعدة البيانات

8) سياسة الملفات الطبية

المريض يرفع الملفات فقط ضمن طلب سريري.

ملف واحد فقط بحالة pending_review لكل طلب.

المريض يستطيع حذف الملف فقط إذا كان pending_review.

بعد approve أو reject: القرار نهائي.

9) Unified Record Tabs Architecture (Mobile-first, Web-safe)
Context

تبويبات الإضبارة داخل /app/record يجب أن تكون:

قابلة للتوسعة

Web-safe

تمنع رجوع مشكلة double-click قدر الإمكان عبر نمط routes ثابت

ملاحظة: معالجة الوميض (flicker) ليست ضمن المطلوب الحالي.

Decision

كل تبويب داخل الإضبارة يمتلك Route مستقل تحت:

/app/record/<tab>

في main.dart
أي Route تابع للإضبارة يبني UserShellScreen:

بدون const

مع:

key: ValueKey<String>(state.uri.path)

داخل UnifiedRecordScreen

قائمة مركزية واحدة (index ↔ path) هي مصدر الحقيقة الوحيد.

إضافة تبويب جديد تعني فقط:

إضافة path واحد

زيادة TabController.length

إضافة Tab + Widget في TabBarView

ممنوع:

TabController listeners

addPostFrameCallback

أي “تصحيح index” بعد البناء

أي منطق توجيه إضافي خارج TabBar.onTap

التوجيه بين تبويبات الإضبارة:

حصريًا عبر TabBar.onTap باستخدام context.go(...).

سياق الطبيب:

patientId يُحافظ عليه عند التنقل

Guard يمنع التوجيه قبل اختيار مريض

Status: معتمد ومطبّق فعليًا، ويُستخدم كأساس لأي تبويب جديد داخل الإضبارة.

10) الإشعارات (ملاحظة تصميمية فقط)

لا يوجد نظام إشعارات حاليًا.

عند تنفيذها لاحقًا:

يجب أن تكون منفصلة عن المنطق الأساسي

ويفضل اتباع نمط event/outbox

(ملاحظة تصميمية فقط بدون تنفيذ حالي.)

11) مراجعة الكود

قائمة مراجعة الكود الرسمية موجودة في:

docs/CODE_REVIEW_CHECKLIST.md

أي كود جديد يجب أن يلتزم بها.

## Appointments – Core Decisions (Phase Appointments MVP)

- Appointment statuses:
  pending, confirmed, cancelled, no_show
- no_show is manual (doctor action)
- Booking for follow-up visits is blocked until required files are approved
- Appointment duration resolution:
  DoctorAppointmentType > AppointmentType.default_duration_minutes
- No scheduling intelligence or prioritization logic in this phase
