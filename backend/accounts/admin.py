from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import (
    CustomUser,
    DoctorDetails,
    PatientDetails,
    AppointmentType,
    DoctorAppointmentType,
    DoctorAvailability,
    Appointment,
    TriageAssessment,
    Governorate,
    Hospital,
    Lab,
)


# ================================
# Custom User Admin
# ================================
from .models import CustomUser, PatientDetails, DoctorDetails

@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    list_display = ('id', 'email', 'username', 'role', 'is_active', 'is_staff')
    list_filter = ('role', 'is_active', 'is_staff')

    fieldsets = (
        (None, {'fields': ('email', 'username', 'password', 'role')}),
        ('Personal Info', {'fields': ('phone', 'governorate', 'address')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'username', 'role', 'password1', 'password2'),
        }),
    )

    search_fields = ('email', 'username')
    ordering = ('email',)



# ================================
# Doctor Details
# ================================
@admin.register(DoctorDetails)
class DoctorDetailsAdmin(admin.ModelAdmin):
    list_display = ('user', 'specialty', 'experience_years', 'is_archived')
    search_fields = ('user__username', 'specialty')


# ================================
# Patient Details
# ================================
@admin.register(PatientDetails)
class PatientDetailsAdmin(admin.ModelAdmin):
    list_display = ('user', 'date_of_birth','gender','blood_type','chronic_disease', 'height', 'weight', 'bmi', 'is_archived')
    list_filter = ('gender','blood_type','is_archived',)

    search_fields = ('user__email','user__full_name','chronic_disease',)


# ================================
# Appointment Type
# ================================
@admin.register(AppointmentType)
class AppointmentTypeAdmin(admin.ModelAdmin):
    list_display = ('type_name', 'created_at', 'updated_at')
    search_fields = ('type_name',)


# ================================
# Doctor Appointment Type
# ================================
@admin.register(DoctorAppointmentType)
class DoctorAppointmentTypeAdmin(admin.ModelAdmin):
    list_display = ('doctor', 'appointment_type', 'duration_minutes')
    list_filter = ('appointment_type',)
    search_fields = ('doctor__username',)


# ================================
# Doctor Availability
# ================================
@admin.register(DoctorAvailability)
class DoctorAvailabilityAdmin(admin.ModelAdmin):
    list_display = ('doctor', 'day_of_week', 'start_time', 'end_time')
    list_filter = ('day_of_week',)
    search_fields = ('doctor__username',)


class TriageAssessmentInline(admin.StackedInline):
    model = TriageAssessment
    extra = 0
    can_delete = False
    readonly_fields = ("created_at",)


# ================================
# Appointment
# ================================
@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    list_display = ('patient', 'doctor', 'appointment_type', 'date_time', 'status')
    list_filter = ('status', 'appointment_type')
    search_fields = ('patient__username', 'doctor__username')
    ordering = ('-date_time',)
    inlines = [TriageAssessmentInline]



# ================================
# TriageAssessment
# ================================
@admin.register(TriageAssessment)
class TriageAssessmentAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "appointment",
        "patient",
        "score",
        "confidence",
        "score_version",
        "created_at",
    )
    list_filter = ("score_version", "score", "created_at")
    search_fields = ("appointment__id", "patient__username", "patient__email")
    ordering = ("-created_at",)


# ================================
# Governorate
# ================================
@admin.register(Governorate)
class GovernorateAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)

# ================================
# Hospital
# ================================
@admin.register(Hospital)
class HospitalAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'governorate', 'address', 'specialty', 'contact_info')
    search_fields = ('name', 'governorate', 'specialty')
# ================================
# Lab
# ================================
@admin.register(Lab)
class LabAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'governorate', 'address', 'specialty', 'contact_info')
    search_fields = ('name', 'governorate', 'specialty')
