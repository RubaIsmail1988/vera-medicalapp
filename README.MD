# Vera Medical App
     :تطبيق مساعد للأطباء والمرضى يوفر منصة ل 
     إدارة المواعيد الطبية مع تقييم أولي اختياري للحالة.
     سجل طبي الكتروني يحوي الطلبات السريرية، الوصفات، الالتزام الدوائي، و بيانات المريض.
     نظام إشعارات محلي.
     بطاقات نصائح.

# تقنيات بناء التطبيق
     Backend: Django REST Framework
     Frontend: Flutter

# هيكلية المشروع
     backend/    # مشروع Django (REST API)
     mobile/     # تطبيق Flutter

# تشغيل Backend (Django) محلياً.
  المتطلبات:
     Python 3.x
     pip
     بيئة افتراضية
  خطوات التشغيل:
    1) إنشاء بيئة افتراضية:
         cd backend
         python -m venv .venv
         تفعيل البيئة:
         .\.venv\Scripts\activate
    2) تثبيت المتطلبات:
         pip install -r ../requirements.txt
    3) تنفيذ migrations:
         python manage.py migrate
    4) إنشاء مستخدم إداري:
         python manage.py createsuperuser
    5) تشغيل السرفر:
         python manage.py runserver
         سيعمل الخادم على http://127.0.0.1:8000/

# تشغيل Frontend (flutter):
   المتطلبات:
      Flutter SDK
      Android Studio أو Emulator
   خطوات التشغيل:
      cd mobile
      flutter pub get
      flutter run

# ربط التطبيق مع السرفر:
    عنوان السرفر موجود بالملف mobile/lib/utils/constants.dart
    المتغير الأساسي هو const String baseUrl = "...";
    1) عند استخدام الخادم المنشور على pythonanywhere:
        const String baseUrl = "https://rubaismail.pythonanywhere.com";
    2) عند تشغيل التطبيق على Android Emulator:
        const String baseUrl = "http://10.0.2.2:8000";
    3) عند تشغيل ال Backend محلياً:
       const String baseUrl = "http://127.0.0.1:8000";
    بعد التعديل:
        flutter clean
        flutter run

# تشغيل خدمة التقييم الأولي (Triage)
     نظام التقييم الأولي يعمل بنمط hybrid
    1) نموذج ذكاء اصطناعي يعمل كخدمة خارجية.
    2) منطق rule-based داخلي يعتمد على العلامات
    3) في حال عدم توفر ml أو فشل الاتصال بها، يعمل النظام تلقائياً باستخدام rule-based فقط.

    لتشغيل المودل كخدمة خارجية يجيب استضافة المودل على سيرفر يحوي مصادر gpu كافية لتشغيل المودل
    ولذلك حاليا تم اعتماد google colab ك خدمة محلية الى حين دراسة كيفية استضافة المودل ك serve دائم

    تشغيل المودل على google colab بحاجة الى:
    - ال checkpoint التي تحوي قيم الأوزان الأخيرة حسب ما تدرب عليه المودل الأساسي (وهو اعطاء تققيم بين 1 و10)
    - الملف الذي يقوم بتشغيل ال server واضافة نقطتين هما:
          - /health للتأكد من صحة ال server
          - /predict الذي يقوم بتشغيل المودل وحساب ال score بناء على ال symptoms-text
    - الملف الذي يقوم بتشغل المودل المطلوب بالأوزان المعدلة والقيام بعملية التقييم

    تم أيضا استخدام ngrok على google colab وذلك لبناء host يتصل مع ال backend للحصول على نتيجة المودل

## ملاحظة مهمة:
خدمة ML لا تعمل تلقائياً داخل Django.
يجب تشغيلها يدوياً عبر google colab
