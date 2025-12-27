from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db import transaction

from clinical.permissions import IsPatient
from .serializers import AppointmentCreateSerializer
from django.db.models import Q
from rest_framework.permissions import IsAuthenticated

from accounts.models import CustomUser, DoctorDetails

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
                "date_time": appointment.date_time,
                "duration_minutes": appointment.duration_minutes,
                "status": appointment.status,
                "notes": appointment.notes,
                "created_at": appointment.created_at,
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