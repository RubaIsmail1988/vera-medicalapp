from django.shortcuts import render
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

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

        order = serializer.save()

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


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsDoctor])
def approve_medical_record_file(request, file_id: int):
    f = MedicalRecordFile.objects.select_related("order").filter(id=file_id).first()
    if not f:
        return Response({"detail": "File not found."}, status=404)

    # Doctor must own the related order
    if not (is_admin(request.user) or f.order.doctor_id == request.user.id):
        return Response({"detail": "You can only review files for your own orders."}, status=403)

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
        rx = serializer.save()

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
        qs = MedicationAdherence.objects.all().select_related("patient", "prescription_item", "prescription_item__prescription")

        if is_admin(user):
            return qs

        if is_patient(user):
            return qs.filter(patient=user)

        if is_doctor(user):
            # Doctor sees adherence for prescriptions they created
            return qs.filter(prescription_item__prescription__doctor=user)

        return qs.none()

    def create(self, request, *args, **kwargs):
        # Patient only (admin allowed)
        if not (is_patient(request.user) or is_admin(request.user)):
            return Response({"detail": "Only patients can record adherence."}, status=403)

        data = request.data.copy()
        data["patient"] = str(request.user.id)

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        log = serializer.save()

        _create_outbox_event(
            event_type="MEDICATION_ADHERENCE_RECORDED",
            actor=request.user,
            patient=request.user,
            obj=log,
            payload={"prescription_item_id": log.prescription_item_id, "status": log.status},
        )

        return Response(MedicationAdherenceSerializer(log).data, status=status.HTTP_201_CREATED)


class OutboxEventListView(generics.ListAPIView):
    """
    للمتابعة الداخلية فقط (اختياري): admin يرى كل شيء.
    doctor/patient يرون الأحداث المرتبطة بهم.
    """
    serializer_class = OutboxEventSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = OutboxEvent.objects.all().select_related("actor", "patient").order_by("-created_at")

        if is_admin(user):
            return qs

        # Narrow to actor/patient matches
        return qs.filter(actor=user) | qs.filter(patient=user)
