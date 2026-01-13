from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from clinical.models import ClinicalOrder, MedicalRecordFile, OutboxEvent
from notifications.services.outbox import process_pending_events
from notifications.services.outbox import try_send_event


class Command(BaseCommand):
    help = "Daily notifications jobs: retry outbox + remind missing uploads for upcoming appointments."

    def handle(self, *args, **options):
        # ---------------------------------------------------------
        # (A) Retry pending outbox events (safety net)
        # ---------------------------------------------------------
        retried = process_pending_events(limit=200)
        self.stdout.write(self.style.SUCCESS(f"Outbox retry processed: {retried} events"))

        # ---------------------------------------------------------
        # (B) Missing uploads reminder (daily)
        # Policy:
        # - look ahead X days
        # - if there is an OPEN ClinicalOrder linked to an appointment
        # - and no files uploaded for that order
        # - remind the patient once per day (we keep it simple)
        # ---------------------------------------------------------
        lookahead_days = 7
        now = timezone.now()
        until = now + timedelta(days=lookahead_days)

        open_orders = (
            ClinicalOrder.objects
            .select_related("patient", "doctor", "appointment")
            .filter(
                status=ClinicalOrder.Status.OPEN,
                appointment__isnull=False,
                appointment__date_time__gte=now,
                appointment__date_time__lte=until,
            )
        )

        reminded = 0

        for order in open_orders:
            # if any file exists for this order => skip
            has_files = MedicalRecordFile.objects.filter(order_id=order.id).exists()
            if has_files:
                continue

            # Create reminder event to patient
            try:
                ev = OutboxEvent.objects.create(
                    event_type="missing_uploads_reminder",
                    actor=None,
                    patient=order.patient,  # recipient = patient
                    object_id=str(order.id),
                    payload={
                        "type": "missing_uploads_reminder",
                        "order_id": order.id,
                        "appointment_id": order.appointment_id,
                        "patient_id": order.patient_id,
                        "doctor_id": order.doctor_id,
                        "order_category": order.order_category,
                        "title": order.title,
                        "timestamp": timezone.now().isoformat(),
                    },
                    status=OutboxEvent.Status.PENDING,
                )
                try_send_event(ev)
                reminded += 1
            except Exception:
                # fail-safe
                pass

        self.stdout.write(self.style.SUCCESS(f"Missing uploads reminders sent: {reminded}"))
