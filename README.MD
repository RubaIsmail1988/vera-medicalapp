# Vera Medical App

تطبيق طبي مساعد يربط بين الأطباء والمرضى ويوفر منصة لإدارة المواعيد الطبية مع نظام تقييم أولي اختياري للحالة.

يشمل النظام:
- إدارة حسابات المرضى والأطباء
- نظام حجز مواعيد
- نظام تقييم أولي (Hybrid ML + Rule-Based)
- سجل طبي إلكتروني (طلبات سريرية، وصفات، التزام دوائي، بيانات المريض)
- بطاقات نصائح صحية
- نظام إشعارات محلي

---

## تحميل التطبيق

[تحميل التطبيق (APK) – الإصدار الرسمي v1.0.0](https://github.com/RubaIsmail1988/vera-medicalapp/releases/tag/v1.0.0)

---

## التقنيات المستخدمة

- **Backend:** Django REST Framework  
- **Frontend:** Flutter  
- **Architecture:** RESTful API  
- **Deployment:** PythonAnywhere  

---

## هيكلية المشروع
- `backend/` → مشروع Django (REST API)
- `mobile/` → تطبيق Flutter

---

## نشر الخادم (Deployment)

تم نشر الخادم الخلفي على PythonAnywhere.  
يتم حفظ متغيرات البيئة (Environment Variables) خارج المستودع لضمان الأمان وعدم تضمين بيانات حساسة داخل GitHub.

---

## تشغيل Backend (Django) محلياً

### المتطلبات:
- Python 3.x
- pip
- بيئة افتراضية (Virtual Environment)

### خطوات التشغيل:

```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r ../requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```
سيعمل الخادم على http://127.0.0.1:8000/

---

## تشغيل Frontend (FLUTTER)

### المتطلبات:
- Flutter SDK
- Android Studio أو Emulator

### خطوات التشغيل:

```bash
cd mobile
flutter pub get
flutter run
```
---

## ربط التطبيق مع الخادم:

- عنوان الخادم موجود بالملف mobile/lib/utils/constants.dart
    المتغير الأساسي هو const String baseUrl = "...";
- عند استخدام الخادم المنشور على pythonanywhere:
        const String baseUrl = "https://rubaismail.pythonanywhere.com";
- عند تشغيل التطبيق على Android Emulator:
        const String baseUrl = "http://10.0.2.2:8000";
- عند تشغيل ال Backend محلياً:
       const String baseUrl = "http://127.0.0.1:8000";
- بعد أي تعديل على الرابط:
        flutter clean
        flutter run
---

## نظام التقييم الأولي (Triage)
يعتمد نظام التقييم الأولي على نمط hybrid يتكون من:
- خدمة ذكاء اصطناعي  خارجية.
- منطق rule-based داخلي يعتمد على العلامات الحيوية
- في حال عدم تشغيل خدمة ml يعمل النظام تلقائياً باستخدام المنطق الداخلي فقط.

---

### ملاحظة مهمة:
خدمة ML لا تعمل تلقائياً داخل Django.
يجب تشغيلها يدوياً عبر google colab
