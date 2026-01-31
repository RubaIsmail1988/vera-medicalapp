from django.contrib.auth import get_user_model
from django.utils import timezone

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import (
    CustomUser,
    DoctorDetails,
    PatientDetails,
    Hospital,
    Lab,
    AccountDeletionRequest,
    AppointmentType,
    DoctorAppointmentType,
    DoctorSpecificVisitType,
    DoctorAvailability,
    Governorate,
)

User = get_user_model()


# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------



class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    governorate_name = serializers.CharField(source="governorate.name", read_only=True)

    class Meta:
        model = CustomUser
        fields = [
            "email",
            "username",
            "password",
            "phone",
            "governorate",
            "governorate_name",
            "address",
            "role",
        ]

    def create(self, validated_data):
        role = validated_data.get("role") or "patient"

     
        is_active = True if role == "patient" else False

        password = validated_data.pop("password")

        user = CustomUser.objects.create_user(
            password=password,
            is_active=is_active,
            **validated_data,
        )
        return user



class DoctorDetailsSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorDetails
        fields = ["user", "specialty", "experience_years", "notes"]

    def validate_user(self, value):
        if value.role == "doctor":
            return value
        raise serializers.ValidationError("هذا المستخدم ليس طبيباً.")


class PatientDetailsSerializer(serializers.ModelSerializer):
    user_id = serializers.PrimaryKeyRelatedField(
        source="user",
        queryset=CustomUser.objects.filter(role="patient"),
    )

    class Meta:
        model = PatientDetails
        fields = [
            "user_id",
            "date_of_birth",
            "height",
            "weight",
            "bmi",
            "gender",
            "blood_type",

            # NEW
            "smoking_status",
            "cigarettes_per_day",
            "alcohol_use",
            "activity_level",
            "has_diabetes",
            "has_hypertension",
            "has_heart_disease",
            "has_asthma_copd",
            "has_kidney_disease",
            "is_pregnant",
            "last_bp_systolic",
            "last_bp_diastolic",
            "bp_measured_at",
            "last_hba1c",
            "hba1c_measured_at",
            "allergies",

            # existing
            "chronic_disease",
            "health_notes",
        ]

    def validate(self, attrs):
        # attrs contains potentially partial updates; merge with instance for checks
        instance = getattr(self, "instance", None)

        gender = attrs.get("gender", getattr(instance, "gender", None))
        is_pregnant = attrs.get("is_pregnant", getattr(instance, "is_pregnant", False))

        smoking_status = attrs.get("smoking_status", getattr(instance, "smoking_status", None))
        cigarettes_per_day = attrs.get("cigarettes_per_day", getattr(instance, "cigarettes_per_day", None))

        if gender != "female" and is_pregnant:
            raise serializers.ValidationError({"is_pregnant": "Pregnancy can only be true when gender is female."})

        if smoking_status != "current" and cigarettes_per_day is not None:
            raise serializers.ValidationError({"cigarettes_per_day": "Only allowed when smoking_status is current."})
        # NEW: convert empty strings to None (NULL in DB)
        for f in ["allergies", "chronic_disease", "health_notes"]:
            if f in attrs and isinstance(attrs[f], str):
                v = attrs[f].strip()
                attrs[f] = v if v else None
        return attrs


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Serializer مخصص لتسجيل الدخول:
    - يتحقق من الإيميل/كلمة المرور يدويًا.
    - يميّز بين:
        * حساب غير موجود / كلمة مرور خاطئة → detail عام.
        * حساب غير مفعّل (is_active=False) → code = "not_active".
    """

    def validate(self, attrs):
        email = attrs.get("email")
        password = attrs.get("password")

        if email is None or password is None:
            raise serializers.ValidationError({"detail": "Email and password are required."})

        try:
            user = CustomUser.objects.get(email=email)
        except CustomUser.DoesNotExist:
            raise serializers.ValidationError({"detail": "No active account found with the given credentials"})

        if not user.check_password(password):
            raise serializers.ValidationError({"detail": "No active account found with the given credentials"})

        if not user.is_active:
            raise serializers.ValidationError(
                {
                    "code": "not_active",
                    "role": getattr(user, "role", None),
                    "detail": "Your account is not activated yet.",
                }
            )

        refresh = self.get_token(user)

        data = {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "role": user.role,
            "is_active": user.is_active,
            "user_id": user.id,
        }

        self.user = user
        return data


class UserSerializer(serializers.ModelSerializer):
    deletion_requests_count = serializers.IntegerField(
        source="deletion_requests.count",
        read_only=True,
    )
    latest_deletion_status = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "role",
            "is_active",
            "deletion_requests_count",
            "latest_deletion_status",
        ]

    def get_latest_deletion_status(self, obj):
        req = obj.deletion_requests.order_by("-created_at").first()
        return req.status if req else None


class CurrentUserSerializer(serializers.ModelSerializer):
    governorate_name = serializers.CharField(source="governorate.name", read_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "role",
            "is_active",
            "phone",
            "governorate",
            "governorate_name",
            "address",
        ]
        read_only_fields = [
            "id",
            "email",
            "role",
            "is_active",
        ]


# ---------------------------------------------------------------------------
# Account deletion
# ---------------------------------------------------------------------------

class AccountDeletionRequestCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = AccountDeletionRequest
        fields = ["reason"]  # المستخدم لا يرسل user ولا status

    def create(self, validated_data):
        user = self.context["request"].user

        if AccountDeletionRequest.objects.filter(user=user, status="pending").exists():
            raise serializers.ValidationError({"detail": "You already have a pending deletion request."})

        return AccountDeletionRequest.objects.create(user=user, **validated_data)


class AccountDeletionRequestListSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_role = serializers.CharField(source="user.role", read_only=True)

    class Meta:
        model = AccountDeletionRequest
        fields = [
            "id",
            "user",
            "user_email",
            "user_role",
            "reason",
            "status",
            "admin_note",
            "processed_by",
            "created_at",
            "processed_at",
        ]
        read_only_fields = [
            "user",
            "user_email",
            "user_role",
            "status",
            "admin_note",
            "processed_by",
            "created_at",
            "processed_at",
        ]


# ---------------------------------------------------------------------------
# Hospitals / Labs
# ---------------------------------------------------------------------------

class HospitalSerializer(serializers.ModelSerializer):
    governorate_name = serializers.CharField(source="governorate.name", read_only=True)

    class Meta:
        model = Hospital
        fields = [
            "id",
            "name",
            "governorate",
            "governorate_name",
            "address",
            "latitude",
            "longitude",
            "specialty",
            "contact_info",
        ]


class LabSerializer(serializers.ModelSerializer):
    governorate_name = serializers.CharField(source="governorate.name", read_only=True)

    class Meta:
        model = Lab
        fields = [
            "id",
            "name",
            "governorate",
            "governorate_name",
            "address",
            "latitude",
            "longitude",
            "specialty",
            "contact_info",
        ]


# ---------------------------------------------------------------------------
# Password reset
# ---------------------------------------------------------------------------

class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)


class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)
    new_password = serializers.CharField(min_length=6, max_length=128)


# ---------------------------------------------------------------------------
# Scheduling (Phase C)
# ---------------------------------------------------------------------------

class AppointmentTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppointmentType
        fields = ["id", "type_name", "description","default_duration_minutes", "created_at", "updated_at"]
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
                raise serializers.ValidationError(
                    {"appointment_type": "This appointment type is already configured for this doctor."}
                )

        return attrs

class DoctorSpecificVisitTypeSerializer(serializers.ModelSerializer):
    doctor = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = DoctorSpecificVisitType
        fields = [
            "id",
            "doctor",
            "name",
            "duration_minutes",
            "description",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "doctor", "created_at", "updated_at"]

    def validate_duration_minutes(self, value):
        if value <= 0:
            raise serializers.ValidationError("duration_minutes must be > 0.")
        return value

    def validate_name(self, value):
        name = (value or "").strip()
        if not name:
            raise serializers.ValidationError("name is required.")
        return name

class DoctorAvailabilitySerializer(serializers.ModelSerializer):
    doctor = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = DoctorAvailability
        fields = ["id", "doctor", "day_of_week", "start_time", "end_time", "created_at", "updated_at"]
        read_only_fields = ["id", "doctor", "created_at", "updated_at"]

    def validate(self, attrs):
        request = self.context.get("request")
        doctor = getattr(request, "user", None) if request else None

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
                raise serializers.ValidationError(
                    {"day_of_week": "Availability for this day already exists for this doctor."}
                )

        return attrs


# ---------------------------------------------------------------------------
# Governorates
# ---------------------------------------------------------------------------

class GovernorateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Governorate
        fields = ["id", "name"]
        read_only_fields = ["id"]
