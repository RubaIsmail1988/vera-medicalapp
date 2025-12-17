from django.contrib import admin

from .models import (
    ClinicalOrder,
    MedicalRecordFile,
    Prescription,
    PrescriptionItem,
    MedicationAdherence,
    OutboxEvent,
)


@admin.register(ClinicalOrder)
class ClinicalOrderAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "order_category",
        "title",
        "status",
        "doctor",
        "patient",
        "appointment",
        "created_at",
    )
    list_filter = ("order_category", "status", "created_at")
    search_fields = ("title", "doctor__email", "patient__email")
    readonly_fields = ("created_at", "updated_at")
    raw_id_fields = ("doctor", "patient", "appointment")


@admin.register(MedicalRecordFile)
class MedicalRecordFileAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "order",
        "patient",
        "review_status",
        "reviewed_by",
        "reviewed_at",
        "uploaded_at",
    )
    list_filter = ("review_status", "uploaded_at", "reviewed_at")
    search_fields = ("patient__email", "doctor_note", "original_filename")
    readonly_fields = ("uploaded_at",)
    raw_id_fields = ("order", "patient", "reviewed_by")


class PrescriptionItemInline(admin.TabularInline):
    model = PrescriptionItem
    extra = 0


@admin.register(Prescription)
class PrescriptionAdmin(admin.ModelAdmin):
    list_display = ("id", "doctor", "patient", "appointment", "created_at")
    list_filter = ("created_at",)
    search_fields = ("doctor__email", "patient__email", "notes")
    readonly_fields = ("created_at",)
    raw_id_fields = ("doctor", "patient", "appointment")
    inlines = (PrescriptionItemInline,)


@admin.register(PrescriptionItem)
class PrescriptionItemAdmin(admin.ModelAdmin):
    list_display = ("id", "prescription", "medicine_name", "start_date", "end_date")
    list_filter = ("start_date", "end_date")
    search_fields = ("medicine_name", "instructions")
    raw_id_fields = ("prescription",)


@admin.register(MedicationAdherence)
class MedicationAdherenceAdmin(admin.ModelAdmin):
    list_display = ("id", "patient", "prescription_item", "status", "taken_at", "created_at")
    list_filter = ("status", "taken_at", "created_at")
    search_fields = ("patient__email", "prescription_item__medicine_name")
    readonly_fields = ("created_at",)
    raw_id_fields = ("patient", "prescription_item")


@admin.register(OutboxEvent)
class OutboxEventAdmin(admin.ModelAdmin):
    list_display = ("id", "event_type", "status", "actor", "patient", "object_id", "created_at")
    list_filter = ("event_type", "status", "created_at")
    search_fields = ("event_type", "object_id", "actor__email", "patient__email")
    readonly_fields = ("created_at",)
    raw_id_fields = ("actor", "patient")
