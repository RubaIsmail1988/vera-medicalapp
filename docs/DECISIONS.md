هذا الملف هو المرجع الرسمي لقرارات المشروع الثابتة.
الكود الموجود على GitHub هو المصدر النهائي للحقيقة، وهذا الملف يوضّح القواعد والقيود المتفق عليها لمنع تكرار العمل أو اتخاذ قرارات متعارضة في المراحل القادمة.

1) حدود النطاق (Scope Boundaries)
ميزات مؤجّلة صراحة

PIN:
ملفات PIN موجودة (screens/pin) لكنها غير مربوطة بالـ flow الحالي.

المواعيد / الحجز / الجدولة:
لم يبدأ تنفيذها بعد.

الإشعارات / التذكيرات:
مؤجّلة لمرحلة لاحقة، ومخطط أن تكون من جهة Flutter.

الذكاء الاصطناعي / التحليلات:
خارج النطاق الحالي.

أي محادثة أو مرحلة جديدة يجب أن تحترم هذه الحدود.

2) التوجيه والتنقل (Routing) — go_router

التطبيق يعتمد على go_router كبنية تنقل أساسية.

يمنع استخدام Navigator.push / pop للتنقل بين الشاشات المرتبطة بالـ routes.

الاستثناء الوحيد:
showDialog و Dialogs المشابهة (ليست تنقل صفحات).

بنية عامة

/ → Splash

مسارات Auth:

/login

/register

/waiting-activation

/forgot-password

/forgot-password/verify

/forgot-password/new

مسارات Admin:

/admin وما تحته (Shell + initialIndex)

تطبيق المستخدم:

كل ما يخص المستخدم يجب أن يكون تحت /app كمسارات أبناء (children).

مبدأ مهم

Refresh أو فتح رابط مباشر يجب ألا يعيد المستخدم بشكل غير متوقّع إلى Splash.

Tab ↔ Route Sync مطبّق حيث يلزم (مثل الإضبارة الطبية).

3) نظام التنبيهات الموحد (SnackBars)

يمنع استخدام ScaffoldMessenger.of(context) مباشرة داخل الشاشات.

يجب استخدام النظام الموحد الموجود في:

mobile/lib/utils/ui_helpers.dart

المرجع الأساسي

rootScaffoldMessengerKey هو المرجع الأساسي لعرض SnackBar.

الهدف:

تفادي مشاكل context after await

تفادي مشاكل go_router

تفادي غياب ScaffoldMessenger في حالات bootstrap

الدوال المعتمدة

showAppSnackBar(...)

showAppErrorSnackBar(...)

showAppSuccessSnackBar(...)

4) Dialog التأكيد (Confirm Dialog)

العمليات الحساسة (حذف، رفض، تعطيل…) يجب أن تستخدم Dialog تأكيد موحّد.

الدالة المعتمدة:

showConfirmDialog(...)
في ui_helpers.dart.

5) الثيم، الثوابت، والـ Helpers

الثيم معتمد ومركزي في:

mobile/lib/theme/app_theme.dart

الثوابت العامة في:

mobile/lib/utils/constants.dart

الـ UI helpers في:

mobile/lib/utils/ui_helpers.dart

يمنع إنشاء أنظمة موازية أو مكررة لنفس الغرض.

6) قواعد تطوير ملزمة (Guardrails)
6.1 SnackBars

أي SnackBar داخل الشاشات يجب أن يستخدم helpers الموحّدة فقط.

6.2 context بعد await

في أي StatefulWidget:

إذا وُجد await ثم استخدام context أو setState أو تنقل،

يجب التحقق:

if (!mounted) return;

6.3 go_router بدل Navigator

في الشاشات المرتبطة بالـ routes:

يستخدم context.go أو context.push.

6.4 الألوان

يمنع استخدام withOpacity.

يستخدم:

withValues(alpha: ...)

6.5 الأزرار أثناء التحميل

أي زر يقوم بعملية async:

يُعطّل أثناء التنفيذ.

يظهر مؤشر تحميل صغير داخل الزر بنفس نمط موحّد.

6.6 منع Rebuild Loops

عند استخدام state.extra أو queryParameters:

يمنع تنفيذ منطق يؤدي إلى setState متكرر داخل build().

يُنقل الاستخراج إلى initState أو didChangeDependencies عند الحاجة.

7) الإضبارة الطبية (Clinical Module)

الكيانات السريرية غير مربوطة إلزاميًا بموعد.

الربط بالمواعيد مؤجّل لمرحلة لاحقة.

لا IDs تُعرض في الواجهة.

Backend (عرض فقط)

تم إضافة حقول read-only في serializers لأغراض العرض فقط:

doctor_display_name

patient_display_name

وفي الالتزام الدوائي: medicine_name, dosage, frequency

لا تغييرات على:

الصلاحيات

الـ endpoints

قاعدة البيانات

8) سياسة الملفات الطبية

المريض يرفع الملفات فقط ضمن طلب سريري.

ملف واحد فقط بحالة pending_review لكل طلب.

المريض يستطيع حذف الملف فقط إذا كان pending_review.

بعد approve أو reject:

القرار نهائي ولا يمكن تغييره.

9) الإشعارات (ملاحظة تصميمية فقط)

لا يوجد نظام إشعارات حاليًا.

عند تنفيذها لاحقًا:

يجب أن تكون منفصلة عن المنطق الأساسي

ويفضّل عبر نمط event / outbox

هذه ملاحظة تصميمية فقط، بدون تنفيذ حالي.

10) مراجعة الكود

قائمة مراجعة الكود الرسمية موجودة في:

docs/CODE_REVIEW_CHECKLIST.md

أي كود جديد يجب أن يلتزم بها.