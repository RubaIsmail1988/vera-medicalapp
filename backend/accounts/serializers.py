from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from .models import CustomUser, DoctorDetails, PatientDetails, Hospital, Lab, AccountDeletionRequest, AppointmentType, DoctorAppointmentType, DoctorAvailability
from django.utils import timezone
from django.contrib.auth import get_user_model
...
User = get_user_model()


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = CustomUser
        fields = ['email', 'username', 'password', 'phone', 'governorate', 'address', 'role']

    def create(self, validated_data):
        role = validated_data.get('role', 'patient')
        is_active = True if role == 'patient' else False

        user = CustomUser.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            username=validated_data['username'],
            phone=validated_data.get('phone'),
            governorate=validated_data.get('governorate'),
            address=validated_data.get('address'),
            role=role,
            is_active=is_active
        )
        return user

class DoctorDetailsSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorDetails
        fields = ['user', 'specialty', 'experience_years', 'notes']

    def validate_user(self, value):
        if value.role == 'doctor':
            return value
        raise serializers.ValidationError("هذا المستخدم ليس طبيباً.")

class PatientDetailsSerializer(serializers.ModelSerializer):
    user_id = serializers.PrimaryKeyRelatedField(
        source='user', queryset=CustomUser.objects.filter(role='patient')
    )

    class Meta:
        model = PatientDetails
        fields = ['user_id', 'date_of_birth', 'height', 'weight', 'bmi', 'gender', 'blood_type', 'chronic_disease', 'health_notes']




class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Serializer مخصص لتسجيل الدخول:
    - يتحقق من الإيميل/كلمة المرور يدويًا.
    - يميّز بين:
        * حساب غير موجود / كلمة مرور خاطئة → detail عام.
        * حساب غير مفعّل (is_active=False) → code = "not_active".
    """

    def validate(self, attrs):
        # 1) نقرأ البريد وكلمة المرور من attrs
        email = attrs.get("email")
        password = attrs.get("password")

        if email is None or password is None:
            raise serializers.ValidationError({
                "detail": "Email and password are required."
            })

        # 2) نحاول جلب المستخدم بالبريد
        try:
            user = CustomUser.objects.get(email=email)
        except CustomUser.DoesNotExist:
            # نفس رسالة SimpleJWT الافتراضية
            raise serializers.ValidationError({
                "detail": "No active account found with the given credentials"
            })

        # 3) نتحقق من كلمة المرور
        if not user.check_password(password):
            # نفس رسالة SimpleJWT الافتراضية
            raise serializers.ValidationError({
                "detail": "No active account found with the given credentials"
            })

        # 4) هنا نعرف أن البريد/الباسورد صحيحة، الآن نفحص is_active
        if not user.is_active:
            # هنا نفرّق بوضوح بين الحساب غير المفعّل وأي حالة أخرى
            raise serializers.ValidationError({
                "code": "not_active",
                "role": getattr(user, 'role', None),
                "detail": "Your account is not activated yet.",
            })

        # 5) في حال المستخدم مفعّل → نُصدر التوكنات كما يفعل TokenObtainPairSerializer
        refresh = self.get_token(user)

        data = {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "role": user.role,
            "is_active": user.is_active,
            "user_id": user.id,
        }

        # مهم: نحتفظ بـ self.user لو احتجناه لاحقًا
        self.user = user

        return data


User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    deletion_requests_count = serializers.IntegerField(
        source='deletion_requests.count',
        read_only=True
    )
    latest_deletion_status = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'role',
            'is_active',
            'deletion_requests_count',
            'latest_deletion_status',
        ]

    def get_latest_deletion_status(self, obj):
        req = obj.deletion_requests.order_by('-created_at').first()
        if req:
            return req.status  # 'pending' / 'approved' / 'rejected'
        return None

class CurrentUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'role',
            'is_active',
            'phone',
            'governorate',
            'address',
        ]
        read_only_fields = [
            'id',
            'email',
            'role',
            'is_active',
        ]



class AccountDeletionRequestCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = AccountDeletionRequest
        fields = ['reason']  # المستخدم لا يرسل user ولا status

    def create(self, validated_data):
        user = self.context['request'].user
        # منع أكثر من طلب pending لنفس المستخدم
        if AccountDeletionRequest.objects.filter(user=user, status='pending').exists():
            raise serializers.ValidationError(
                {"detail": "You already have a pending deletion request."}
            )
        return AccountDeletionRequest.objects.create(user=user, **validated_data)


class AccountDeletionRequestListSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source='user.email', read_only=True)
    user_role = serializers.CharField(source='user.role', read_only=True)

    class Meta:
        model = AccountDeletionRequest
        fields = [
            'id',
            'user',
            'user_email',
            'user_role',
            'reason',
            'status',
            'admin_note',
            'processed_by',
            'created_at',
            'processed_at',
        ]
        read_only_fields = [
            'user',
            'user_email',
            'user_role',
            'status',
            'admin_note',
            'processed_by',
            'created_at',
            'processed_at',
        ]



# Serializer للمشافي
class HospitalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hospital
        fields = ['id', 'name', 'governorate', 'address', 'latitude', 'longitude', 'specialty', 'contact_info']

# Serializer للمخابر
class LabSerializer(serializers.ModelSerializer):
    class Meta:
        model = Lab
        fields = ['id', 'name', 'governorate', 'address', 'latitude', 'longitude', 'specialty', 'contact_info']

from django.contrib.auth import get_user_model
from rest_framework import serializers

User = get_user_model()

class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()

class PasswordResetVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)

class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)
    new_password = serializers.CharField(min_length=6, max_length=128)

class AppointmentTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppointmentType
        fields = ["id", "type_name", "description", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class DoctorAppointmentTypeSerializer(serializers.ModelSerializer):
    doctor = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = DoctorAppointmentType
        fields = ["id", "doctor", "appointment_type", "duration_minutes"]
        read_only_fields = ["id", "doctor"]

    def validate_duration_minutes(self, value):
        if value <= 0:
            raise serializers.ValidationError("duration_minutes must be > 0.")
        return value
    def validate(self, attrs):
        request = self.context.get("request")
        doctor = getattr(request, "user", None) if request else None

        appointment_type = attrs.get("appointment_type")
        if doctor and appointment_type:
            if DoctorAppointmentType.objects.filter(
                doctor=doctor,
                appointment_type=appointment_type,
            ).exists():
              raise serializers.ValidationError({
                "appointment_type": "This appointment type is already configured for this doctor."
              })
        return attrs

from .models import DoctorAvailability

class DoctorAvailabilitySerializer(serializers.ModelSerializer):
    doctor = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = DoctorAvailability
        fields = ["id", "doctor", "day_of_week", "start_time", "end_time", "created_at", "updated_at"]
        read_only_fields = ["id", "doctor", "created_at", "updated_at"]

    def validate(self, attrs):
        request = self.context.get("request")
        doctor = getattr(request, "user", None)

        day_of_week = attrs.get("day_of_week")
        start_time = attrs.get("start_time")
        end_time = attrs.get("end_time")

        if start_time and end_time and start_time >= end_time:
            raise serializers.ValidationError("start_time must be earlier than end_time.")

        if doctor and day_of_week:
            exists = DoctorAvailability.objects.filter(
                doctor=doctor,
                day_of_week=day_of_week,
            ).exists()
            if exists:
                raise serializers.ValidationError({
                    "day_of_week": "Availability for this day already exists for this doctor."
                })

        return attrs
