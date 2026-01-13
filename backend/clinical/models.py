from django.conf import settings
from django.db import models
from django.utils import timezone

class ClinicalOrder(models.Model):
    class OrderCategory(models.TextChoices):
        LAB_TEST = "lab_test", "Lab Test"
        MEDICAL_IMAGING = "medical_imaging", "Medical Imaging"

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        FULFILLED = "fulfilled", "Fulfilled"
        CANCELLED = "cancelled", "Cancelled"

    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="clinical_orders_created",
    )
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="clinical_orders_received",
    )

    order_category = models.CharField(max_length=32, choices=OrderCategory.choices)
    title = models.CharField(max_length=255)
    details = models.TextField(blank=True)

    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.OPEN,
    )

    # Optional future link (out of scope logic now)
    appointment = models.ForeignKey(
        "accounts.Appointment",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="clinical_orders",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"{self.order_category} - {self.title}"


class MedicalRecordFile(models.Model):
    class ReviewStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    order = models.ForeignKey(
        ClinicalOrder,
        on_delete=models.CASCADE,
        related_name="files",
    )

    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="medical_record_files",
    )

    file = models.FileField(upload_to="medical_records/")
    original_filename = models.CharField(max_length=255, blank=True)

    review_status = models.CharField(
        max_length=16,
        choices=ReviewStatus.choices,
        default=ReviewStatus.PENDING,
    )
    doctor_note = models.TextField(blank=True)

    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_medical_record_files",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)

    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"File #{self.pk} ({self.review_status})"


class Prescription(models.Model):
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="prescriptions_created",
    )
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="prescriptions_received",
    )

    # Optional future link (out of scope logic now)
    appointment = models.ForeignKey(
        "accounts.Appointment",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="prescriptions",
    )

    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"Rx #{self.pk}"


class PrescriptionItem(models.Model):
    prescription = models.ForeignKey(
        Prescription,
        on_delete=models.CASCADE,
        related_name="items",
    )

    medicine_name = models.CharField(max_length=255)
    dosage = models.CharField(max_length=255, blank=True)
    frequency = models.CharField(max_length=255, blank=True)

    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)

    instructions = models.TextField(blank=True)

    def __str__(self) -> str:
        return self.medicine_name


class MedicationAdherence(models.Model):
    class Status(models.TextChoices):
        TAKEN = "taken", "Taken"
        SKIPPED = "skipped", "Skipped"

    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="medication_adherence_logs",
    )
    prescription_item = models.ForeignKey(
        PrescriptionItem,
        on_delete=models.CASCADE,
        related_name="adherence_logs",
    )

    status = models.CharField(max_length=16, choices=Status.choices, default=Status.TAKEN)
    taken_at = models.DateTimeField()

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"Adherence #{self.pk} ({self.status})"


class OutboxEvent(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        SENT = "sent", "Sent"
        FAILED = "failed", "Failed"

    event_type = models.CharField(max_length=64)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="outbox_events_as_actor",
    )
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="outbox_events_as_patient",
    )

    object_id = models.CharField(max_length=64, blank=True)
    payload = models.JSONField(default=dict, blank=True)

    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PENDING,
    )

    attempts = models.PositiveIntegerField(default=0)
    last_error = models.TextField(blank=True, null=True)
    sent_at = models.DateTimeField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def mark_sent(self):
        self.status = self.Status.SENT
        self.sent_at = timezone.now()
        self.last_error = None

    def mark_failed(self, error: str):
        self.status = self.Status.FAILED
        self.last_error = (error or "")[:2000]

    def __str__(self) -> str:
        return f"{self.event_type} ({self.status})"

