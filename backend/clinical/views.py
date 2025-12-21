from django.shortcuts import render
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404

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


def _create_outbox_event(*, event_type: str, actor, patient=None, obj=None, payload=None):
    # تسجيل فقط، دائماً PENDING
    try:
        OutboxEvent.objects.create(
            event_type=event_type,
            actor=actor if getattr(actor, "is_authenticated", False) else None,
            patient=patient,
            object_id=str(getattr(obj, "id", "")) if obj is not None else "",
            payload=payload or {},
            status=OutboxEvent.Status.PENDING,
        )
    except Exception:
        # Fail-safe: لا نفشل العملية الأساسية إذا فشل تسجيل الحدث
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
        from accounts.models import Appointment  # عدّل المسار إذا لزم
        if Appointment.objects.filter(doctor_id=doctor.id, patient_id=patient_id).exists():
            return True
    except Exception:
        # Appointment model may not exist / import path differs; ignore safely
        pass

    return False



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

        # If role is unknown, restrict to none for safety
        return qs.none()

    def create(self, request, *args, **kwargs):
        # Doctor only (admin allowed)
        if not (is_doctor(request.user) or is_admin(request.user)):
            return Response({"detail": "Only doctors can create clinical orders."}, status=403)

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        patient = serializer.validated_data.get("patient")
        patient_id = getattr(patient, "id", None)

        if patient_id is None:
            return Response({"patient": "patient is required."}, status=400)

        if is_doctor(request.user) and not _doctor_is_linked_to_patient(doctor=request.user, patient_id=patient_id):
            return Response({"detail": "You cannot create orders for this patient."}, status=403)


        order = serializer.save(doctor=request.user)

        _create_outbox_event(
            event_type="CLINICAL_ORDER_CREATED",
            actor=request.user,
            patient=order.patient,
            obj=order,
            payload={"order_category": order.order_category, "title": order.title},
        )

        return Response(ClinicalOrderSerializer(order).data, status=status.HTTP_201_CREATED)


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

        # Owner access via order ownership
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

        # Ensure patient owns the order
        if not (is_admin(request.user) or (order.patient_id == request.user.id)):
            return Response({"detail": "You can only upload files for your own orders."}, status=403)

        data = request.data.copy()
        data["order"] = str(order_id)
        data["patient"] = str(request.user.id)

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        file_obj = serializer.save()

        _create_outbox_event(
            event_type="MEDICAL_FILE_UPLOADED",
            actor=request.user,
            patient=order.patient,
            obj=file_obj,
            payload={"order_id": order.id, "filename": file_obj.original_filename},
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
    - (اختياري) تسجيل OutboxEvent MEDICAL_FILE_DELETED (Pending)
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request, file_id):
        record_file = get_object_or_404(MedicalRecordFile, pk=file_id)

        user = request.user

        # admin مسموح دائمًا
        if is_admin(user):
            if getattr(record_file, "file", None):
                record_file.file.delete(save=False)
            record_file.delete()

            _create_outbox_event(
                event_type="MEDICAL_FILE_DELETED",
                actor=user,
                patient=getattr(record_file, "patient", None),
                obj=record_file,
                payload={"reason": "deleted_by_admin"},
            )

            return Response(status=status.HTTP_204_NO_CONTENT)

        # patient مسموح فقط إذا الملف له + pending
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
                payload={"reason": "deleted_by_patient"},
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

    # Doctor must own the related order
    if not (is_admin(request.user) or f.order.doctor_id == request.user.id):
        return Response({"detail": "You can only review files for your own orders."}, status=403)

    # Lock decision: لا يسمح بالمراجعة إذا الملف لم يعد pending
    if not _is_pending_review_status(getattr(f, "review_status", "")):
        return Response({"detail": "File already reviewed."}, status=status.HTTP_409_CONFLICT)

    f.review_status = MedicalRecordFile.ReviewStatus.APPROVED
    f.reviewed_by = request.user
    f.reviewed_at = timezone.now()
    f.doctor_note = request.data.get("doctor_note", "") or ""
    f.save(update_fields=["review_status", "reviewed_by", "reviewed_at", "doctor_note"])

    _create_outbox_event(
        event_type="MEDICAL_FILE_REVIEWED",
        actor=request.user,
        patient=f.order.patient,
        obj=f,
        payload={"review_status": f.review_status, "order_id": f.order_id},
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

    # Lock decision: لا يسمح بالمراجعة إذا الملف لم يعد pending
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

    _create_outbox_event(
        event_type="MEDICAL_FILE_REVIEWED",
        actor=request.user,
        patient=f.order.patient,
        obj=f,
        payload={"review_status": f.review_status, "order_id": f.order_id},
    )

    return Response(MedicalRecordFileSerializer(f).data)


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

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        patient = serializer.validated_data.get("patient")
        patient_id = getattr(patient, "id", None)

        if patient_id is None:
            return Response({"patient": "patient is required."}, status=400)

        if is_doctor(request.user) and not _doctor_is_linked_to_patient(doctor=request.user, patient_id=patient_id):
            return Response({"detail": "You cannot create prescriptions for this patient."}, status=403)

        rx = serializer.save(doctor=request.user)

        _create_outbox_event(
            event_type="PRESCRIPTION_CREATED",
            actor=request.user,
            patient=rx.patient,
            obj=rx,
            payload={"items_count": rx.items.count()},
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
            # Doctor sees adherence for prescriptions they created
            return qs.filter(prescription_item__prescription__doctor=user)

        return qs.none()

    def create(self, request, *args, **kwargs):
        if not (is_patient(request.user) or is_admin(request.user)):
            return Response({"detail": "Only patients can record adherence."}, status=403)

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        #  Force patient من السيرفر دائمًا
        log = serializer.save(patient=request.user)

        _create_outbox_event(
            event_type="MEDICATION_ADHERENCE_RECORDED",
            actor=request.user,
            patient=request.user,
            obj=log,
            payload={"prescription_item_id": log.prescription_item_id, "status": log.status},
        )

        return Response(MedicationAdherenceSerializer(log, context={"request": request}).data, status=status.HTTP_201_CREATED)


class ClinicalRecordAggregationView(APIView):
    """
    GET /api/clinical/record/?patient_id=...
    Read-only aggregation within role scope.

    - Admin: sees all data for patient
    - Doctor: sees only data created by that doctor for the patient
    - Patient: (option A) only self
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

        # -------------------------
        # Scope resolution
        # -------------------------
        if is_admin(user):
            orders_qs = ClinicalOrder.objects.filter(patient_id=patient_id).select_related("doctor", "patient", "appointment")
            rx_qs = Prescription.objects.filter(patient_id=patient_id).select_related("doctor", "patient", "appointment").prefetch_related("items")
            adh_qs = MedicationAdherence.objects.filter(patient_id=patient_id).select_related(
                "patient", "prescription_item", "prescription_item__prescription"
            )
            scope = {"role": "admin", "admin_id": user.id}

        elif is_doctor(user):
            # Doctor scope: only what this doctor created for this patient
            orders_qs = ClinicalOrder.objects.filter(doctor=user, patient_id=patient_id).select_related("doctor", "patient", "appointment")
            rx_qs = Prescription.objects.filter(doctor=user, patient_id=patient_id).select_related("doctor", "patient", "appointment").prefetch_related("items")
            adh_qs = MedicationAdherence.objects.filter(
                patient_id=patient_id,
                prescription_item__prescription__doctor=user,
            ).select_related("patient", "prescription_item", "prescription_item__prescription")
            scope = {"role": "doctor", "doctor_id": user.id}

        elif is_patient(user):
            # Option A : patient can only access their own record aggregation
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

        # -------------------------
        # Serialize
        # -------------------------
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

class OutboxEventListView(generics.ListAPIView):
    serializer_class = OutboxEventSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = OutboxEvent.objects.all().select_related("actor", "patient").order_by("-created_at")

        if is_admin(user):
            return qs

        return qs.none()

