from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.db import models
from django.utils import timezone
from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator

# نموذج المحافظة المرجعية
class Governorate(models.Model):
    name = models.CharField(max_length=150, unique=True)

    def __str__(self):
        return self.name

# مدير المستخدمين
class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('يجب توفير البريد الإلكتروني')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('يجب أن يكون المشرف موظفاً')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('يجب أن يكون المشرف مسؤولاً')
        return self.create_user(email, password, **extra_fields)

# نموذج المستخدم المخصص
class CustomUser(AbstractBaseUser, PermissionsMixin):
    ROLE_CHOICES = [
        ('admin', 'Admin'),
        ('doctor', 'Doctor'),
        ('patient', 'Patient'),
    ]
    
    email = models.EmailField(unique=True)
    username = models.CharField(max_length=150)
    phone = models.CharField(max_length=20, blank=True, null=True)
    governorate = models.ForeignKey(Governorate, on_delete=models.SET_NULL, null=True, blank=True)
    address = models.TextField(blank=True, null=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, blank=True, null=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, blank=True, null=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='patient')
    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=False)  # سيبقى غير مفعل للطبيب تلقائيًا
    date_joined = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    objects = CustomUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return f"{self.email} ({self.role})"

# نموذج طلب حذف حساب 
class AccountDeletionRequest(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='deletion_requests',
    )
    reason = models.TextField(blank=True, null=True)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
    )

    admin_note = models.TextField(blank=True, null=True)
    processed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='processed_deletion_requests',
    )
    created_at = models.DateTimeField(default=timezone.now)
    processed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"DeletionRequest #{self.id} - {self.user.email} - {self.status}"



# نموذج تفاصيل الطبيب
class DoctorDetails(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, primary_key=True)
    specialty = models.CharField(max_length=150)
    experience_years = models.PositiveIntegerField()
    notes = models.TextField(blank=True, null=True)
    is_archived = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.user.username} - {self.specialty}"

# نموذج تفاصيل المريض
class PatientDetails(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, primary_key=True)
    date_of_birth = models.DateField()
    height = models.FloatField(blank=True, null=True)
    weight = models.FloatField(blank=True, null=True)
    bmi = models.FloatField(blank=True, null=True)
    GENDER_CHOICES = [
        ('male', 'Male'),
        ('female', 'Female'),
    ]
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, blank=True, null=True)

    BLOOD_TYPES = [
        ('A+', 'A+'), ('A-', 'A-'),
        ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'),
        ('O+', 'O+'), ('O-', 'O-'),
    ]
    blood_type = models.CharField(max_length=3, choices=BLOOD_TYPES, blank=True, null=True)

    chronic_disease = models.TextField(blank=True, null=True)    
    health_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    is_archived = models.BooleanField(default=False)
    

    

    def __str__(self):
        return f"{self.user.username} - Patient"


#------------------------------
#reset password
#-----------------------------
from django.utils import timezone
from datetime import timedelta
import secrets

class PasswordResetOTP(models.Model):
    """
    OTP لإعادة تعيين كلمة المرور عبر البريد.
    - يُرسل للمستخدم كرمز 6 أرقام.
    - صالح لمدة محددة.
    - يُستخدم مرة واحدة.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="password_reset_otps")
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)

    @staticmethod
    def generate_code():
        # 6 digits
        return f"{secrets.randbelow(1000000):06d}"

    @staticmethod
    def default_expiry_minutes():
        return 10

    @classmethod
    def create_for_user(cls, user, minutes=None):
        if minutes is None:
            minutes = cls.default_expiry_minutes()
        now = timezone.now()
        return cls.objects.create(
            user=user,
            code=cls.generate_code(),
            created_at=now,
            expires_at=now + timedelta(minutes=minutes),
            is_used=False,
        )

    def is_expired(self):
        return timezone.now() > self.expires_at

    def __str__(self):
        return f"PasswordResetOTP(user={self.user.email}, code={self.code}, used={self.is_used})"

#------------------------------
#Appointment Type
#-----------------------------

class AppointmentType(models.Model):
    type_name = models.CharField(max_length=150, unique=True)
    description = models.TextField(blank=True, null=True)
    default_duration_minutes = models.PositiveIntegerField(
        default=15,
        validators=[MinValueValidator(1)],
    )
    requires_approved_files = models.BooleanField(default=False)    
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["type_name"]

    def __str__(self):
        return self.type_name
    
# -----------------------------
# أنواع زيارة الطبيب الخاصة به (مدة محددة لكل طبيب)
# -----------------------------
class DoctorAppointmentType(models.Model):
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="doctor_appointment_types",
        limit_choices_to={"role": "doctor"},
    )
    appointment_type = models.ForeignKey(
        AppointmentType,
        on_delete=models.CASCADE,
        related_name="doctor_appointment_types",
    )
    duration_minutes = models.PositiveIntegerField(validators=[MinValueValidator(1)])

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["doctor", "appointment_type"],
                name="uniq_doctor_appointment_type",
            ),
        ]

    def __str__(self):
        return f"{self.doctor.username} - {self.appointment_type.type_name}"

# -----------------------------
# أنواع زيارة الطبيب الخاصة به (نوع محدد لكل طبيب)
# -----------------------------

class DoctorSpecificVisitType(models.Model):
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="doctor_specific_visit_types",
        limit_choices_to={"role": "doctor"},
    )
    name = models.CharField(max_length=150)
    duration_minutes = models.PositiveIntegerField(validators=[MinValueValidator(1)])
    description = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["doctor", "name"]
        constraints = [
            models.UniqueConstraint(
                fields=["doctor", "name"],
                name="uniq_doctor_specific_visit_type_name",
            ),
        ]

    def __str__(self):
        return f"{self.doctor.username} - {self.name} ({self.duration_minutes}m)"


# -----------------------------
# أوقات توافر الطبيب
# -----------------------------
class DoctorAvailability(models.Model):
    DAYS_OF_WEEK = [
        ("Monday", "Monday"),
        ("Tuesday", "Tuesday"),
        ("Wednesday", "Wednesday"),
        ("Thursday", "Thursday"),
        ("Friday", "Friday"),
        ("Saturday", "Saturday"),
        ("Sunday", "Sunday"),
    ]

    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="availabilities",
        limit_choices_to={"role": "doctor"},
    )
    day_of_week = models.CharField(max_length=10, choices=DAYS_OF_WEEK)
    start_time = models.TimeField()
    end_time = models.TimeField()
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["doctor", "day_of_week"],
                name="uniq_doctor_day_of_week",
            ),
            models.CheckConstraint(
                check=models.Q(start_time__lt=models.F("end_time")),
                name="chk_start_time_before_end_time",
            ),
        ]
        ordering = ["doctor", "day_of_week", "start_time"]

    def __str__(self):
        return f"{self.doctor.username} - {self.day_of_week}: {self.start_time}-{self.end_time}"

# -----------------------------
# المواعيد
# -----------------------------
class Appointment(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('cancelled', 'Cancelled'),
        ('no_show', 'No Show'),

    ]
    patient = models.ForeignKey('CustomUser', on_delete=models.CASCADE, related_name='patient_appointments', limit_choices_to={'is_staff': False})
    doctor = models.ForeignKey('CustomUser', on_delete=models.CASCADE, related_name='doctor_appointments', limit_choices_to={'is_staff': False})
    appointment_type = models.ForeignKey(AppointmentType, on_delete=models.CASCADE)
    date_time = models.DateTimeField()
    duration_minutes = models.PositiveIntegerField(blank=True, null=True)  # يمكن أخذها من DoctorAppointmentType
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.patient.username} with {self.doctor.username} on {self.date_time}"

#-----------------------------
# التقييم الأولي
#-----------------------------
class TriageAssessment(models.Model):
    SCORE_VERSION_V1 = "triage_v1"

    appointment = models.OneToOneField(
        Appointment,
        on_delete=models.CASCADE,
        related_name="triage",
    )

    # redundancy مفيدة للفلترة/القراءة السريعة (ويمكن استنتاجها من appointment.patient)
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="triage_assessments",
        limit_choices_to={"role": "patient"},
    )

    symptoms_text = models.TextField(blank=True, null=True)

    temperature_c = models.DecimalField(
        max_digits=4,
        decimal_places=1,
        blank=True,
        null=True,
        validators=[MinValueValidator(30.0), MaxValueValidator(45.0)],
    )

    bp_systolic = models.PositiveSmallIntegerField(
        blank=True,
        null=True,
        validators=[MinValueValidator(50), MaxValueValidator(260)],
    )
    bp_diastolic = models.PositiveSmallIntegerField(
        blank=True,
        null=True,
        validators=[MinValueValidator(30), MaxValueValidator(160)],
    )

    heart_rate = models.PositiveSmallIntegerField(
        blank=True,
        null=True,
        validators=[MinValueValidator(30), MaxValueValidator(240)],
    )

    score = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(10)]
    )

    confidence = models.PositiveSmallIntegerField(
        blank=True,
        null=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Confidence based on completeness of inputs.",
    )

    missing_fields = models.JSONField(default=list, blank=True)

    score_version = models.CharField(
        max_length=32,
        default=SCORE_VERSION_V1,
    )

    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        indexes = [
            models.Index(fields=["patient", "created_at"]),
            models.Index(fields=["score", "created_at"]),
        ]

    def __str__(self):
        return f"Triage(appointment_id={self.appointment_id}, score={self.score})"


class Hospital(models.Model):
    name = models.CharField(max_length=200)
    governorate = models.ForeignKey(Governorate, on_delete=models.CASCADE, related_name='hospitals')
    address = models.TextField(blank=True, null=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    specialty = models.CharField(max_length=200, blank=True, null=True)
    contact_info = models.CharField(max_length=200, blank=True, null=True)

    def __str__(self):
        return self.name

class Lab(models.Model):
    name = models.CharField(max_length=200)
    governorate = models.ForeignKey(Governorate, on_delete=models.CASCADE, related_name='labs')
    address = models.TextField(blank=True, null=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    specialty = models.CharField(max_length=200, blank=True, null=True)
    contact_info = models.CharField(max_length=200, blank=True, null=True)

    def __str__(self):
        return self.name


class DoctorAbsence(models.Model):
    TYPE_CHOICES = [
        ("planned", "Planned"),
        ("emergency", "Emergency"),
    ]

    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="absences",
        limit_choices_to={"role": "doctor"},
    )
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default="planned")
    notes = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-start_time"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(start_time__lt=models.F("end_time")),
                name="chk_absence_start_before_end",
            ),
        ]

    def __str__(self):
        return f"{self.doctor.username} absence {self.start_time} -> {self.end_time}"


    
