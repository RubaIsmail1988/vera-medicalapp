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

        # ضمان أن أي superuser يكون دوره admin (حتى لا يذهب إلى /app)
        extra_fields.setdefault('role', 'admin')

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
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True
    )

    date_of_birth = models.DateField()
    height = models.FloatField(blank=True, null=True)   # لاحقًا ممكن نخليها cm int
    weight = models.FloatField(blank=True, null=True)
    bmi = models.FloatField(blank=True, null=True)

    class Gender(models.TextChoices):
        MALE = "male", "Male"
        FEMALE = "female", "Female"

    gender = models.CharField(
        max_length=10,
        choices=Gender.choices,
        blank=True,
        null=True
    )

    BLOOD_TYPES = [
        ('A+', 'A+'), ('A-', 'A-'),
        ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'),
        ('O+', 'O+'), ('O-', 'O-'),
    ]
    blood_type = models.CharField(max_length=3, choices=BLOOD_TYPES, blank=True, null=True)

    # --- NEW: Lifestyle
    class SmokingStatus(models.TextChoices):
        NEVER = "never", "Never"
        FORMER = "former", "Former"
        CURRENT = "current", "Current"

    smoking_status = models.CharField(
        max_length=10,
        choices=SmokingStatus.choices,
        default=SmokingStatus.NEVER
    )
    cigarettes_per_day = models.PositiveSmallIntegerField(blank=True, null=True)

    class AlcoholUse(models.TextChoices):
        NONE = "none", "None"
        OCCASIONAL = "occasional", "Occasional"
        REGULAR = "regular", "Regular"

    alcohol_use = models.CharField(
        max_length=12,
        choices=AlcoholUse.choices,
        default=AlcoholUse.NONE
    )

    class ActivityLevel(models.TextChoices):
        LOW = "low", "Low"
        MODERATE = "moderate", "Moderate"
        HIGH = "high", "High"

    activity_level = models.CharField(
        max_length=10,
        choices=ActivityLevel.choices,
        default=ActivityLevel.MODERATE
    )

    # --- NEW: Chronic conditions (structured)
    has_diabetes = models.BooleanField(default=False)
    has_hypertension = models.BooleanField(default=False)
    has_heart_disease = models.BooleanField(default=False)
    has_asthma_copd = models.BooleanField(default=False)
    has_kidney_disease = models.BooleanField(default=False)

    # --- NEW: Pregnancy (depends on gender)
    is_pregnant = models.BooleanField(default=False)

    # --- NEW: Optional measurements
    last_bp_systolic = models.PositiveSmallIntegerField(blank=True, null=True)
    last_bp_diastolic = models.PositiveSmallIntegerField(blank=True, null=True)
    bp_measured_at = models.DateTimeField(blank=True, null=True)

    last_hba1c = models.FloatField(blank=True, null=True)
    hba1c_measured_at = models.DateField(blank=True, null=True)

    # Existing free-text fields (keep for now)
    chronic_disease = models.TextField(blank=True, null=True)
    health_notes = models.TextField(blank=True, null=True)

    allergies = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    is_archived = models.BooleanField(default=False)
  
    def __str__(self):
        return f"{self.user.username} - Patient"
   
    def save(self, *args, **kwargs):
        # enforce pregnancy consistency
        if self.gender != self.Gender.FEMALE:
            self.is_pregnant = False

        # enforce cigarettes_per_day consistency
        if self.smoking_status != self.SmokingStatus.CURRENT:
            self.cigarettes_per_day = None
        # auto-calculate BMI if possible
        if self.height and self.weight:
            height_m = self.height / 100.0  # assuming height stored in cm
            if height_m > 0:
                self.bmi = round(self.weight / (height_m * height_m), 2)
        else:
            self.bmi = None
        super().save(*args, **kwargs)


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

# -----------------------------
# Scheduling Policy Add-ons
# -----------------------------

class UrgentRequest(models.Model):
    """
    Waitlist / Urgent intake when no slots are available.
    Created by patient when triage is high and booking cannot be satisfied.
    """
    STATUS_CHOICES = [
        ("open", "Open"),
        ("handled", "Handled"),
        ("rejected", "Rejected"),
        ("cancelled", "Cancelled"),
    ]

    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="urgent_requests",
        limit_choices_to={"role": "patient"},
    )
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="urgent_requests_received",
        limit_choices_to={"role": "doctor"},
    )
    appointment_type = models.ForeignKey(
        AppointmentType,
        on_delete=models.CASCADE,
        related_name="urgent_requests",
    )
    handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="urgent_requests_handled",
        limit_choices_to={"role": "doctor"},
    )

    rejected_reason = models.TextField(blank=True, null=True)

    # triage snapshot (not linked to Appointment)
    symptoms_text = models.TextField(blank=True, null=True)
    temperature_c = models.DecimalField(max_digits=4, decimal_places=1, blank=True, null=True)
    bp_systolic = models.PositiveSmallIntegerField(blank=True, null=True)
    bp_diastolic = models.PositiveSmallIntegerField(blank=True, null=True)
    heart_rate = models.PositiveSmallIntegerField(blank=True, null=True)

    score = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(10)],
        blank=True,
        null=True,
    )
    confidence = models.PositiveSmallIntegerField(
        blank=True,
        null=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    missing_fields = models.JSONField(default=list, blank=True)
    score_version = models.CharField(max_length=32, blank=True, null=True)

    notes = models.TextField(blank=True, null=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="open")
    HANDLED_TYPE_CHOICES = [
        ("scheduled", "Scheduled"),
        ("rejected", "Rejected"),
    ]

    handled_type = models.CharField(
        max_length=20,
        choices=HANDLED_TYPE_CHOICES,
        blank=True,
        null=True,
    )

    scheduled_appointment = models.ForeignKey(
        "accounts.Appointment",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="from_urgent_request",
    )
    created_at = models.DateTimeField(default=timezone.now)
    handled_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["doctor", "status", "created_at"]),
            models.Index(fields=["patient", "created_at"]),
            models.Index(fields=["score", "created_at"]),
        ]

    def __str__(self):
        return f"UrgentRequest(patient={self.patient_id}, doctor={self.doctor_id}, score={self.score}, status={self.status})"


class RebookingPriorityToken(models.Model):
    """
    Token granted to patients whose appointments were cancelled due to emergency absence.
    Used to give them a fair advantage when rebooking.
    """
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="rebooking_tokens",
        limit_choices_to={"role": "patient"},
    )
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="rebooking_tokens_issued",
        limit_choices_to={"role": "doctor"},
    )
    absence = models.ForeignKey(
        "DoctorAbsence",
        on_delete=models.CASCADE,
        related_name="rebooking_tokens",
        blank=True,
        null=True,
    )

    issued_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()

    is_active = models.BooleanField(default=True)
    # NEW
    consumed_at = models.DateTimeField(null=True, blank=True)
    consumed_appointment = models.ForeignKey(
        "accounts.Appointment",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="consumed_rebooking_tokens",
    )
    class Meta:
        ordering = ["-issued_at"]

        indexes = [
            # البحث عن توكن فعّال للمريض عند الحجز
            models.Index(fields=["patient", "doctor", "is_active", "expires_at"]),

            # دعم الاستعلامات القديمة (لو استُخدمت بمكان آخر)
            models.Index(fields=["patient", "is_active", "expires_at"]),
            models.Index(fields=["doctor", "is_active", "expires_at"]),

            # NEW: الربط العكسي من الموعد ← التوكن المستهلك
            models.Index(fields=["consumed_appointment"]),
        ]

        constraints = [
            # سلامة زمنية أساسية
            models.CheckConstraint(
                condition=models.Q(issued_at__lt=models.F("expires_at")),
                name="chk_token_issued_before_expires",
            ),

            # إذا استُهلك التوكن، يجب أن يكون غير فعّال
            models.CheckConstraint(
                condition=(
                    models.Q(consumed_at__isnull=True, consumed_appointment__isnull=True)
                    | models.Q(is_active=False)
                ),
                name="chk_consumed_token_is_inactive",
            ),
        ]


    def __str__(self):
        return f"RebookingToken(patient={self.patient_id}, doctor={self.doctor_id}, active={self.is_active})"


class AbsenceCancellationLog(models.Model):
    """
    Minimal audit for cancellations triggered by emergency absence.
    (Keeps thesis-friendly traceability without changing Appointment schema.)
    """
    absence = models.ForeignKey(
        "DoctorAbsence",
        on_delete=models.CASCADE,
        related_name="cancellation_logs",
    )
    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.CASCADE,
        related_name="absence_cancellation_logs",
    )
    cancelled_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-cancelled_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["absence", "appointment"],
                name="uniq_absence_appointment_cancel_log",
            ),
        ]

    def __str__(self):
        return f"AbsenceCancellationLog(absence={self.absence_id}, appt={self.appointment_id})"

    
