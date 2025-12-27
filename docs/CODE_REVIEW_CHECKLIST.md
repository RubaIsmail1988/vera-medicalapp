1) Flutter — القواعد العامة
1.1 التعامل مع async و context

❑ عند وجود await ثم استخدام:

context

setState

تنقل (go / push)

يجب دائمًا التحقق:

if (!mounted) return;

1.2 SnackBars

❑ يمنع استخدام ScaffoldMessenger.of(context) مباشرة.

❑ يجب استخدام الدوال الموحّدة فقط:

showAppSnackBar

showAppErrorSnackBar

showAppSuccessSnackBar

❑ المرجع:
mobile/lib/utils/ui_helpers.dart

1.3 Dialogs

❑ العمليات الحساسة (حذف، رفض، تعطيل…) يجب أن تستخدم:

showConfirmDialog

❑ يمنع إنشاء Dialogs مكررة لنفس الغرض.

1.4 Routing & Navigation

❑ الشاشات المرتبطة بالـ routes يجب أن تستخدم:

context.go

context.push

❑ يمنع استخدام Navigator.push / pop للتنقل الأساسي.

❑ Dialogs (showDialog) مسموحة.

❑ أي شاشة يمكن الوصول لها من:

Bottom Navigation

Tabs
يجب أن تمتلك Route صريح (Web-safe) إن كانت ضمن نطاق الويب.

1.5 Lifecycle & Controllers

❑ أي Controller مستخدم (مثل):

TextEditingController

TabController

ScrollController

أي Controller مخصص

يجب:

التخلص منه داخل dispose()

يمنع ترك Controller بدون dispose

2) Flutter — UI / UX
2.1 الألوان والثيم

❑ يمنع استخدام withOpacity.

❑ يستخدم:

withValues(alpha: ...)


❑ يجب احترام الثيم المركزي:

mobile/lib/theme/app_theme.dart

❑ يمنع إنشاء أنظمة ثيم موازية.

2.2 حالات التحميل (Loading / Disabled)

❑ أي زر ينفّذ عملية async:

يُعطّل أثناء التنفيذ

يظهر مؤشر تحميل صغير داخل الزر

❑ يمنع السماح بالضغط المتكرر أثناء التحميل.

2.3 حالات العرض

❑ يجب التعامل بوضوح مع الحالات التالية:

Loading

Empty

Error

❑ يمنع ترك الشاشة فارغة أو بدون رسالة للمستخدم.

2.4 منع Rebuild Loops

❑ يمنع تنفيذ setState داخل build() بناءً على:

state.extra

queryParameters

❑ عند الحاجة:

يُنقل المنطق إلى initState

أو didChangeDependencies بحذر

3) Flutter — Naming & Code Style
3.1 المتغيرات

❑ يمنع استخدام _ كبادئة لمتغيرات محلية.

❑ _ مخصص فقط للأعضاء الخاصة (private members).

3.2 الثوابت

❑ استخدام lowerCamelCase للثوابت (حسب نمط المشروع).

❑ الثوابت العامة تُوضع في:

constants.dart

3.3 Imports

❑ إزالة أي import غير مستخدم.

❑ ترتيب imports منطقيًا:

SDK

packages

project

4) Backend (Django) — عند وجود تعديل
4.1 Serializers

❑ أي حقل مضاف لأغراض العرض فقط يجب أن يكون:

read_only

❑ يمنع نقل منطق العرض إلى الواجهة إذا كان يمكن توفيره من الـ serializer.

4.2 الصلاحيات

❑ أي تعديل يجب أن يحترم الصلاحيات الحالية.

❑ يمنع توسيع الصلاحيات بدون قرار صريح موثّق.

4.3 قاعدة البيانات

❑ لا migrations بدون سبب واضح.

❑ لا تغيير على models خارج نطاق المرحلة الحالية.

4.4 Atomic Operations

❑ العمليات التي:

تُنشئ أكثر من سجل

أو تعتمد على uniqueness / قيود تكامل

يُفضّل تغليفها بـ:

transaction.atomic()

5) عام

❑ لا IDs في الواجهة.

❑ لا منطق مواعيد أو إشعارات قبل مرحلتها.

❑ لا إعادة هيكلة كبيرة بدون قرار موثّق في DECISIONS.md.

❑ GitHub هو المصدر الرسمي للحقيقة.

ملاحظة أخيرة

هذه القائمة ملزمة وليست إرشادية.

أي استثناء يجب أن يكون:

مبررًا

ومذكورًا صراحة في النقاش أو القرار

✔ بهذه الصيغة، القائمة مغلقة ومعتمدة
✔ جاهزة للاستخدام في كل مراجعة قادمة
✔ متوافقة مع ما نُفّذ فعليًا في المشروع