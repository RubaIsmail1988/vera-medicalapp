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

# نظام التقييم الأولي (Triage)
     يعتمد نظام التقييم الأولي على نمط hybrid يتكون من:
    1) خدمة ذكاء اصطناعي  خارجية.
    2) منطق rule-based داخلي يعتمد على العلامات الحيوية
    3) في حال عدم تشغيل خدمة ml يعمل النظام تلقائياً باستخدام المنطق الداخلي فقط.

## ملاحظة مهمة:
خدمة ML لا تعمل تلقائياً داخل Django.
يجب تشغيلها يدوياً عبر google colab
