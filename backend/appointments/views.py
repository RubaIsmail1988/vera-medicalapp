from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import api_view, permission_classes
from django.db import transaction
from django.shortcuts import get_object_or_404

from clinical.permissions import IsPatient,IsDoctor
from .serializers import AppointmentCreateSerializer
from django.db.models import Q
from rest_framework.permissions import IsAuthenticated

from accounts.models import CustomUser, DoctorDetails, Appointment


class AppointmentCreateView(APIView):
    permission_classes = [IsPatient]

    @transaction.atomic
    def post(self, request):
        serializer = AppointmentCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        appointment = serializer.save()

        return Response(
            {
                "id": appointment.id,
                "patient": appointment.patient_id,
                "doctor": appointment.doctor_id,
                "appointment_type": appointment.appointment_type_id,
                "date_time": appointment.date_time.isoformat().replace("+00:00", "Z"),
                "duration_minutes": appointment.duration_minutes,
                "status": appointment.status,
                "notes": appointment.notes,
                "created_at": appointment.created_at.isoformat().replace("+00:00", "Z"),
            },
            status=status.HTTP_201_CREATED,
        )

    
    
class DoctorSearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        q = (request.query_params.get("q") or "").strip()
        if not q:
            return Response({"results": []})

        # Find doctors by username OR specialty
        doctor_ids_by_specialty = DoctorDetails.objects.filter(
            Q(specialty__icontains=q)
        ).values_list("user_id", flat=True)

        doctors = CustomUser.objects.filter(
            role="doctor"
        ).filter(
            Q(username__icontains=q) | Q(id__in=doctor_ids_by_specialty)
        ).order_by("username")[:50]

        results = [
            {
                "id": d.id,
                "username": d.username,
                "email": d.email,
                "specialty": DoctorDetails.objects.filter(user_id=d.id).values_list("specialty", flat=True).first(),
            }
            for d in doctors
        ]

        return Response({"results": results})
    
@api_view(["POST"])
@permission_classes([IsDoctor])
def mark_no_show(request, pk: int):
    user = request.user

    appointment = get_object_or_404(Appointment, pk=pk)

    # Must belong to this doctor
    if appointment.doctor_id != user.id:
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    # Basic state guard
    if appointment.status == "cancelled":
        return Response(
            {"detail": "Cancelled appointments cannot be marked as no_show."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    appointment.status = "no_show"
    appointment.save(update_fields=["status", "updated_at"])

    return Response(
        {
            "id": appointment.id,
            "status": appointment.status,
        },
        status=status.HTTP_200_OK,
    )

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def cancel_appointment(request, pk: int):
    user = request.user
    appointment = get_object_or_404(Appointment, pk=pk)

    is_admin = bool(getattr(user, "is_staff", False) or getattr(user, "is_superuser", False) or getattr(user, "role", "") == "admin")
    is_owner_patient = appointment.patient_id == user.id
    is_owner_doctor = appointment.doctor_id == user.id

    if not (is_admin or is_owner_patient or is_owner_doctor):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    if appointment.status == "no_show":
        return Response(
            {"detail": "no_show appointments cannot be cancelled."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if appointment.status == "cancelled":
        return Response(
            {"id": appointment.id, "status": appointment.status},
            status=status.HTTP_200_OK,
        )

    appointment.status = "cancelled"
    appointment.save(update_fields=["status", "updated_at"])

    return Response(
        {"id": appointment.id, "status": appointment.status},
        status=status.HTTP_200_OK,
    )