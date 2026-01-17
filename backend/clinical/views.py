from django.utils import timezone
from django.shortcuts import get_object_or_404

from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    ClinicalOrder,
    MedicalRecordFile,
    Prescription,
    MedicationAdherence,
    OutboxEvent,
)
from .permissions import IsDoctor, IsPatient, is_admin, is_doctor, is_patient
from .serializers import (
    ClinicalOrderSerializer,
    MedicalRecordFileCreateSerializer,
    MedicalRecordFileSerializer,
    PrescriptionSerializer,
    MedicationAdherenceSerializer,
    OutboxEventSerializer,
)
from accounts.models import Appointment
from notifications.services.outbox import try_send_event


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _display_name(u):
    if not u:
        return None

    full_name = getattr(u, "get_full_name", None)
    if callable(full_name) and full_name():
        return full_name()

    return getattr(u, "username", None) or getattr(u, "email", None) or f"User #{u.id}"


def _create_outbox_event(*, event_type: str, actor, patient=None, obj=None, payload=None):
    """
    Create Outbox event safely (fail-safe, does not break main flow).

    NOTE:
    - OutboxEvent.patient = recipient (may be patient OR doctor).
    - This helper enriches payload with display names and unified keys for Flutter.
    """
    try:
        actor_user = actor if getattr(actor, "is_authenticated", False) else None
        recipient_user = patient

        base = payload.copy() if isinstance(payload, dict) else {}

        # Unified keys
        base.setdefault("type", event_type)
        base.setdefault("entity_id", getattr(obj, "id", None) if obj is not None else None)

        base.setdefault("actor_id", getattr(actor_user, "id", None))
        base.setdefault("actor_name", _display_name(actor_user))

        base.setdefault("recipient_id", getattr(recipient_user, "id", None))
        base.setdefault("recipient_name", _display_name(recipient_user))

        # Optional roles (if CustomUser.role exists)
        if actor_user is not None:
            base.setdefault("actor_role", getattr(actor_user, "role", None))
        if recipient_user is not None:
            base.setdefault("recipient_role", getattr(recipient_user, "role", None))

        base.setdefault("timestamp", timezone.now().isoformat())

        # Ready-to-show defaults
        if not str(base.get("title") or "").strip():
            base["title"] = event_type
        if not str(base.get("message") or "").strip():
            base["message"] = "تفاصيل غير متوفرة."

        ev = OutboxEvent.objects.create(
            event_type=event_type,
            actor=actor_user,
            patient=recipient_user,
            object_id=str(getattr(obj, "id", "")) if obj is not None else "",
            payload=base,
            status=OutboxEvent.Status.PENDING,
        )

        try:
            try_send_event(ev)
        except Exception:
            pass

    except Exception:
        # Fail-safe
        pass


def _is_pending_review_status(value: str) -> bool:
    """
    توحيد التعامل مع pending:
    - بعض ردود API عندكم كانت "pending"
    - السياسة الجديدة تسميها "pending_review"
    """
    v = (value or "").strip().lower()
    return v in ("pending", "pending_review", "pending-review")


def _doctor_is_linked_to_patient(*, doctor, patient_id: int) -> bool:
    # 1) Existing clinical relationship via previous Orders
    if ClinicalOrder.objects.filter(doctor=doctor, patient_id=patient_id).exists():
        return True

    # 2) Existing clinical relationship via previous Prescriptions
    if Prescription.objects.filter(doctor=doctor, patient_id=patient_id).exists():
        return True

    # 3) Optional: if Appointment exists already, use it as a stronger link
    try:
        if Appointment.objects.filter(doctor_id=doctor.id, patient_id=patient_id).exists():
            return True
    except Exception:
        pass

    return False


# ---------------------------------------------------------------------------
# Clinical Orders
# ---------------------------------------------------------------------------

class ClinicalOrderListCreateView(generics.ListCreateAPIView):
    serializer_class = ClinicalOrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = ClinicalOrder.objects.all().select_related("doctor", "patient", "appointment")

        if is_admin(user):
            return qs
        if is_doctor(user):
            return qs.filter(doctor=user)
        if is_patient(user):
            return qs.filter(patient=user)

        return qs.none()

    def create(self, request, *args, **kwargs):
        # Doctor only (admin allowed)
        if not (is_doctor(request.user) or is_admin(request.user)):
            return Response({"detail": "Only doctors can create clinical orders."}, status=403)

        appointment_id = request.data.get("appointment")
        if not appointment_id:
            return Response({"appointment": "appointment is required."}, status=400)

        try:
            appointment_id = int(appointment_id)
        except (TypeError, ValueError):
            return Response({"appointment": "appointment must be an integer."}, status=400)

        appt = (
            Appointment.objects.select_related("doctor", "patient")
            .filter(id=appointment_id)
            .first()
        )
        if not appt:
            return Response({"detail": "Appointment not found."}, status=404)

        # Resolve actor doctor
        if is_admin(request.user):
            resolved_doctor = appt.doctor
        else:
            resolved_doctor = request.user
            if appt.doctor_id != resolved_doctor.id:
                return Response({"detail": "Not found."}, status=404)

        # Gate: must be confirmed to create clinical activity
        if appt.status in ["cancelled", "no_show"]:
            return Response(
                {"detail": f"Cannot create order for appointment in status '{appt.status}'."},
                status=status.HTTP_409_CONFLICT,
            )

        if appt.status != "confirmed":
            return Response(
                {"detail": "Appointment must be confirmed before creating clinical orders."},
                status=status.HTTP_409_CONFLICT,
            )

        # Client must NOT send patient (derived from appointment)
        data = request.data.copy()

        raw_patient = data.get("patient", None)
        if raw_patient is not None and str(raw_patient).strip() != "":
            return Response(
                {"patient": ["Do not send patient. It is derived from appointment."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        data.pop("patient", None)

        forced_patient = appt.patient

        data["patient"] = str(forced_patient.id)
        data["appointment"] = str(appt.id)

        serializer = self.get_serializer(
            data=data,
            context={**self.get_serializer_context(), "patient_from_appointment": True},
        )
        serializer.is_valid(raise_exception=True)

        order = serializer.save(
            doctor=resolved_doctor,
            patient=forced_patient,
            appointment=appt,
        )

        _create_outbox_event(
            event_type="CLINICAL_ORDER_CREATED",
            actor=resolved_doctor,
            patient=order.patient,
            obj=order,
            payload={
                "order_category": order.order_category,
                "title": "طلب تحليل/صورة",
                "message": f"طلب: {order.title}",
                "appointment_id": appt.id,
                "order_id": order.id,
                "patient_id": order.patient_id,
                "doctor_id": order.doctor_id,
                "route": f"/app/record/orders/{order.id}?role=doctor",
            },
        )

        return Response(
            ClinicalOrderSerializer(order).data,
            status=status.HTTP_201_CREATED,
        )


class ClinicalOrderRetrieveView(generics.RetrieveAPIView):
    serializer_class = ClinicalOrderSerializer
    permission_classes = [IsAuthenticated]
    queryset = ClinicalOrder.objects.all().select_related("doctor", "patient", "appointment")

    def retrieve(self, request, *args, **kwargs):
        obj = self.get_object()
        user = request.user

        if is_admin(user):
            return super().retrieve(request, *args, **kwargs)

        if is_doctor(user) and obj.doctor_id == user.id:
            return super().retrieve(request, *args, **kwargs)

        if is_patient(user) and obj.patient_id == user.id:
            return super().retrieve(request, *args, **kwargs)

        return Response({"detail": "Not found."}, status=404)


# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

class OrderFilesListView(generics.ListAPIView):
    serializer_class = MedicalRecordFileSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        order_id = self.kwargs["order_id"]
        qs = MedicalRecordFile.objects.filter(order_id=order_id).select_related(
            "order", "patient", "reviewed_by"
        )

        user = self.request.user
        if is_admin(user):
            return qs

        order = ClinicalOrder.objects.filter(id=order_id).first()
        if not order:
            return MedicalRecordFile.objects.none()

        if is_doctor(user) and order.doctor_id == user.id:
            return qs

        if is_patient(user) and order.patient_id == user.id:
            return qs

        return MedicalRecordFile.objects.none()


class OrderFileUploadView(generics.CreateAPIView):
    serializer_class = MedicalRecordFileCreateSerializer
    permission_classes = [IsAuthenticated, IsPatient]
    parser_classes = [MultiPartParser, FormParser]

    def create(self, request, *args, **kwargs):
        order_id = self.kwargs["order_id"]
        order = ClinicalOrder.objects.filter(id=order_id).first()
        if not order:
            return Response({"detail": "Clinical order not found."}, status=404)

        if not (is_admin(request.user) or (order.patient_id == request.user.id)):
            return Response({"detail": "You can only upload files for your own orders."}, status=403)

        data = request.data.copy()
        data["order"] = str(order_id)
        data["patient"] = str(request.user.id)

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        file_obj = serializer.save()

        # Notifications: file_uploaded -> recipient = doctor
        _create_outbox_event(
            event_type="file_uploaded",
            actor=request.user,          # patient
            patient=order.doctor,        # recipient doctor
            obj=file_obj,
            payload={
                "title": "تم رفع ملف طبي",
                "message": f"تم رفع الملف: {file_obj.original_filename or 'ملف جديد'}",
                "order_id": order.id,
                "patient_id": order.patient_id,
                "doctor_id": order.doctor_id,
                "filename": file_obj.original_filename,
                "route": "/app/record/files",
            },
        )

        return Response(MedicalRecordFileSerializer(file_obj).data, status=status.HTTP_201_CREATED)


class OrderFileDeleteView(APIView):
    """
    DELETE /api/clinical/files/<file_id>/

    - admin: مسموح دائمًا
    - patient: فقط إذا:
        - file.patient_id == request.user.id
        - file.review_status == pending (يدعم pending / pending_review)
      غير ذلك: 403
    - عند الحذف: حذف من storage ثم حذف السجل
    - تسجيل OutboxEvent MEDICAL_FILE_DELETED (Pending)
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request, file_id):
        record_file = get_object_or_404(MedicalRecordFile, pk=file_id)
        user = request.user

        if is_admin(user):
            if getattr(record_file, "file", None):
                record_file.file.delete(save=False)
            record_file.delete()

            _create_outbox_event(
                event_type="MEDICAL_FILE_DELETED",
                actor=user,
                patient=getattr(record_file, "patient", None),
                obj=record_file,
                payload={
                    "reason": "deleted_by_admin",
                    "title": "تم حذف ملف",
                    "message": "تم حذف الملف بواسطة الإدارة.",
                    "route": "/app/record/files",
                },
            )
            return Response(status=status.HTTP_204_NO_CONTENT)

        if is_patient(user):
            if getattr(record_file, "patient_id", None) != getattr(user, "id", None):
                return Response(
                    {"detail": "You do not have permission to delete this file."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if not _is_pending_review_status(getattr(record_file, "review_status", "")):
                return Response(
                    {"detail": "You can only delete a pending file."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if getattr(record_file, "file", None):
                record_file.file.delete(save=False)
            record_file.delete()

            _create_outbox_event(
                event_type="MEDICAL_FILE_DELETED",
                actor=user,
                patient=getattr(record_file, "patient", None),
                obj=record_file,
                payload={
                    "reason": "deleted_by_patient",
                    "title": "تم حذف ملف",
                    "message": "تم حذف الملف بنجاح.",
                    "route": "/app/record/files",
                },
            )
            return Response(status=status.HTTP_204_NO_CONTENT)

        return Response(
            {"detail": "You do not have permission to delete this file."},
            status=status.HTTP_403_FORBIDDEN,
        )


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsDoctor])
def approve_medical_record_file(request, file_id: int):
    f = MedicalRecordFile.objects.select_related("order").filter(id=file_id).first()
    if not f:
        return Response({"detail": "File not found."}, status=404)

    if not (is_admin(request.user) or f.order.doctor_id == request.user.id):
        return Response({"detail": "You can only review files for your own orders."}, status=403)

    if not _is_pending_review_status(getattr(f, "review_status", "")):
        return Response({"detail": "File already reviewed."}, status=status.HTTP_409_CONFLICT)

    f.review_status = MedicalRecordFile.ReviewStatus.APPROVED
    f.reviewed_by = request.user
    f.reviewed_at = timezone.now()
    f.doctor_note = request.data.get("doctor_note", "") or ""
    f.save(update_fields=["review_status", "reviewed_by", "reviewed_at", "doctor_note"])

    order = f.order

    has_approved = MedicalRecordFile.objects.filter(
        order_id=order.id,
        patient_id=order.patient_id,
        review_status=MedicalRecordFile.ReviewStatus.APPROVED,
    ).exists()

    if has_approved and order.status != ClinicalOrder.Status.FULFILLED:
        order.status = ClinicalOrder.Status.FULFILLED
        order.save(update_fields=["status", "updated_at"])

    # Notifications: file_reviewed -> recipient = patient
    _create_outbox_event(
        event_type="file_reviewed",
        actor=request.user,
        patient=f.order.patient,
        obj=f,
        payload={
            "title": "تمت مراجعة ملف",
            "message": f"حالة المراجعة: {f.review_status}",
            "order_id": f.order_id,
            "patient_id": f.order.patient_id,
            "doctor_id": f.order.doctor_id,
            "review_status": f.review_status,
            "route": "/app/record/files",
        },
    )

    return Response(MedicalRecordFileSerializer(f).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsDoctor])
def reject_medical_record_file(request, file_id: int):
    f = MedicalRecordFile.objects.select_related("order").filter(id=file_id).first()
    if not f:
        return Response({"detail": "File not found."}, status=404)

    if not (is_admin(request.user) or f.order.doctor_id == request.user.id):
        return Response({"detail": "You can only review files for your own orders."}, status=403)

    if not _is_pending_review_status(getattr(f, "review_status", "")):
        return Response({"detail": "File already reviewed."}, status=status.HTTP_409_CONFLICT)

    doctor_note = request.data.get("doctor_note", "") or ""
    if not doctor_note.strip():
        return Response({"doctor_note": "doctor_note is required when rejecting."}, status=400)

    f.review_status = MedicalRecordFile.ReviewStatus.REJECTED
    f.reviewed_by = request.user
    f.reviewed_at = timezone.now()
    f.doctor_note = doctor_note
    f.save(update_fields=["review_status", "reviewed_by", "reviewed_at", "doctor_note"])

    # Notifications: file_reviewed -> recipient = patient
    _create_outbox_event(
        event_type="file_reviewed",
        actor=request.user,
        patient=f.order.patient,
        obj=f,
        payload={
            "title": "تمت مراجعة ملف",
            "message": f"حالة المراجعة: {f.review_status}",
            "order_id": f.order_id,
            "patient_id": f.order.patient_id,
            "doctor_id": f.order.doctor_id,
            "review_status": f.review_status,
            "route": "/app/record/files",
        },
    )

    return Response(MedicalRecordFileSerializer(f).data)


# ---------------------------------------------------------------------------
# Prescriptions
# ---------------------------------------------------------------------------

class PrescriptionListCreateView(generics.ListCreateAPIView):
    serializer_class = PrescriptionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Prescription.objects.all().select_related("doctor", "patient", "appointment").prefetch_related("items")

        if is_admin(user):
            return qs
        if is_doctor(user):
            return qs.filter(doctor=user)
        if is_patient(user):
            return qs.filter(patient=user)
        return qs.none()

    def create(self, request, *args, **kwargs):
        if not (is_doctor(request.user) or is_admin(request.user)):
            return Response({"detail": "Only doctors can create prescriptions."}, status=403)

        appointment_id = request.data.get("appointment")
        if not appointment_id:
            return Response({"appointment": "appointment is required."}, status=400)

        try:
            appointment_id = int(appointment_id)
        except (TypeError, ValueError):
            return Response({"appointment": "appointment must be an integer."}, status=400)

        appt = (
            Appointment.objects.select_related("doctor", "patient")
            .filter(id=appointment_id)
            .first()
        )
        if not appt:
            return Response({"detail": "Appointment not found."}, status=404)

        if is_admin(request.user):
            resolved_doctor = appt.doctor
        else:
            resolved_doctor = request.user
            if appt.doctor_id != resolved_doctor.id:
                return Response({"detail": "Not found."}, status=404)

        if appt.status in ["cancelled", "no_show"]:
            return Response(
                {"detail": f"Cannot create prescription for appointment in status '{appt.status}'."},
                status=status.HTTP_409_CONFLICT,
            )

        if appt.status != "confirmed":
            return Response(
                {"detail": "Appointment must be confirmed before creating prescriptions."},
                status=status.HTTP_409_CONFLICT,
            )

        raw_patient = request.data.get("patient", None)
        if raw_patient is not None and str(raw_patient).strip() != "":
            return Response(
                {"patient": ["Do not send patient. It is derived from appointment."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        forced_patient = appt.patient

        data = request.data.copy()
        data["patient"] = str(forced_patient.id)
        data["appointment"] = str(appt.id)

        serializer = self.get_serializer(
            data=data,
            context={**self.get_serializer_context(), "patient_from_appointment": True},
        )
        serializer.is_valid(raise_exception=True)

        rx = serializer.save(
            doctor=resolved_doctor,
            patient=forced_patient,
            appointment=appt,
        )

        _create_outbox_event(
            event_type="PRESCRIPTION_CREATED",
            actor=resolved_doctor,
            patient=rx.patient,
            obj=rx,
            payload={
                "title": "وصفة جديدة",
                "message": f"تم إنشاء وصفة جديدة. عدد الأدوية: {rx.items.count()}",
                "items_count": rx.items.count(),
                "appointment_id": appt.id,
                "prescription_id": rx.id,
                "route": "/app/record/prescripts",
            },
        )

        return Response(PrescriptionSerializer(rx).data, status=status.HTTP_201_CREATED)


class PrescriptionRetrieveView(generics.RetrieveAPIView):
    serializer_class = PrescriptionSerializer
    permission_classes = [IsAuthenticated]
    queryset = Prescription.objects.all().select_related("doctor", "patient", "appointment").prefetch_related("items")

    def retrieve(self, request, *args, **kwargs):
        obj = self.get_object()
        user = request.user

        if is_admin(user):
            return super().retrieve(request, *args, **kwargs)

        if is_doctor(user) and obj.doctor_id == user.id:
            return super().retrieve(request, *args, **kwargs)

        if is_patient(user) and obj.patient_id == user.id:
            return super().retrieve(request, *args, **kwargs)

        return Response({"detail": "Not found."}, status=404)


# ---------------------------------------------------------------------------
# Medication Adherence
# ---------------------------------------------------------------------------

class MedicationAdherenceListCreateView(generics.ListCreateAPIView):
    serializer_class = MedicationAdherenceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = MedicationAdherence.objects.all().select_related(
            "patient", "prescription_item", "prescription_item__prescription"
        )

        if is_admin(user):
            return qs

        if is_patient(user):
            return qs.filter(patient=user)

        if is_doctor(user):
            return qs.filter(prescription_item__prescription__doctor=user)

        return qs.none()

    def create(self, request, *args, **kwargs):
        if not (is_patient(request.user) or is_admin(request.user)):
            return Response({"detail": "Only patients can record adherence."}, status=403)

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        log = serializer.save(patient=request.user)

        _create_outbox_event(
            event_type="MEDICATION_ADHERENCE_RECORDED",
            actor=request.user,
            patient=request.user,
            obj=log,
            payload={
                "title": "تسجيل التزام دوائي",
                "message": f"تم تسجيل الحالة: {log.status}",
                "prescription_item_id": log.prescription_item_id,
                "status": log.status,
                "route": "/app/record/adherence",
            },
        )

        return Response(
            MedicationAdherenceSerializer(log, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

class ClinicalRecordAggregationView(APIView):
    """
    GET /api/clinical/record/?patient_id=...
    Read-only aggregation within role scope.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        patient_id_raw = request.query_params.get("patient_id")
        if not patient_id_raw:
            return Response({"patient_id": "patient_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            patient_id = int(patient_id_raw)
        except ValueError:
            return Response({"patient_id": "patient_id must be an integer."}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user

        if is_admin(user):
            orders_qs = ClinicalOrder.objects.filter(patient_id=patient_id).select_related("doctor", "patient", "appointment")
            rx_qs = Prescription.objects.filter(patient_id=patient_id).select_related("doctor", "patient", "appointment").prefetch_related("items")
            adh_qs = MedicationAdherence.objects.filter(patient_id=patient_id).select_related(
                "patient", "prescription_item", "prescription_item__prescription"
            )
            scope = {"role": "admin", "admin_id": user.id}

        elif is_doctor(user):
            orders_qs = ClinicalOrder.objects.filter(doctor=user, patient_id=patient_id).select_related("doctor", "patient", "appointment")
            rx_qs = Prescription.objects.filter(doctor=user, patient_id=patient_id).select_related("doctor", "patient", "appointment").prefetch_related("items")
            adh_qs = MedicationAdherence.objects.filter(
                patient_id=patient_id,
                prescription_item__prescription__doctor=user,
            ).select_related("patient", "prescription_item", "prescription_item__prescription")
            scope = {"role": "doctor", "doctor_id": user.id}

        elif is_patient(user):
            if user.id != patient_id:
                return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

            orders_qs = ClinicalOrder.objects.filter(patient=user).select_related("doctor", "patient", "appointment")
            rx_qs = Prescription.objects.filter(patient=user).select_related("doctor", "patient", "appointment").prefetch_related("items")
            adh_qs = MedicationAdherence.objects.filter(patient=user).select_related(
                "patient", "prescription_item", "prescription_item__prescription"
            )
            scope = {"role": "patient", "patient_id": user.id}

        else:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

        orders_data = ClinicalOrderSerializer(orders_qs, many=True, context={"request": request}).data
        prescriptions_data = PrescriptionSerializer(rx_qs, many=True, context={"request": request}).data
        adherence_data = MedicationAdherenceSerializer(adh_qs, many=True, context={"request": request}).data

        return Response(
            {
                "patient_id": patient_id,
                "scope": scope,
                "orders": orders_data,
                "prescriptions": prescriptions_data,
                "adherence": adherence_data,
                "counts": {
                    "orders": len(orders_data),
                    "prescriptions": len(prescriptions_data),
                    "adherence": len(adherence_data),
                },
            },
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# Outbox / Inbox
# ---------------------------------------------------------------------------

class OutboxEventListView(generics.ListAPIView):
    serializer_class = OutboxEventSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = OutboxEvent.objects.all().select_related("actor", "patient").order_by("-created_at")

        if is_admin(user):
            return qs

        return qs.none()


class MyInboxEventsView(generics.ListAPIView):
    """
    GET /api/clinical/inbox/
    Inbox = events where current user is the recipient.
    NOTE: OutboxEvent.patient field is used as recipient in DB.

    Optional filters:
      - ?status=pending|sent|failed
      - ?since_id=123   (only events with id > since_id)
      - ?event_type=appointment_created (exact match)
      - ?limit=50       (caps results)
    """
    serializer_class = OutboxEventSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        # IMPORTANT for polling with since_id:
        # sort by id ASC to guarantee stable incremental delivery
        qs = (
            OutboxEvent.objects
            .filter(patient_id=user.id)   # recipient
            .order_by("id")
        )

        status_param = (self.request.query_params.get("status") or "").strip().lower()
        if status_param in ("pending", "sent", "failed"):
            qs = qs.filter(status=status_param)

        event_type = (self.request.query_params.get("event_type") or "").strip()
        if event_type:
            qs = qs.filter(event_type=event_type)

        since_id_raw = (self.request.query_params.get("since_id") or "").strip()
        if since_id_raw:
            try:
                since_id = int(since_id_raw)
                qs = qs.filter(id__gt=since_id)
            except ValueError:
                pass

        limit_raw = (self.request.query_params.get("limit") or "").strip()
        try:
            limit = int(limit_raw) if limit_raw else 100
        except ValueError:
            limit = 100

        limit = max(1, min(limit, 200))
        return qs[:limit]
