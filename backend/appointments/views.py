from collections import defaultdict
from datetime import datetime, timedelta

from django.db import transaction
from django.db.models import Q
from django.http import Http404
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from clinical.permissions import IsPatient, IsDoctor
from clinical.models import (
    ClinicalOrder,
    MedicalRecordFile,
    Prescription,
    MedicationAdherence,
    OutboxEvent,
)

# NOTE:
# لديك try_send_event ضمن outbox services. إذا أردت لاحقًا إلغاء الـ push بالكامل
# يمكنك إزالة try_send_event من هذا الملف، لكن سنتركه الآن لتجنب كسر أي شيء.
from notifications.services.outbox import try_send_event

from accounts.models import (
    Appointment,
    AppointmentType,
    CustomUser,
    DoctorAbsence,
    DoctorAppointmentType,
    DoctorAvailability,
    DoctorDetails,
    DoctorSpecificVisitType,
)

from .permissions import IsDoctorOrAdmin
from .serializers import (
    AppointmentCreateSerializer,
    DoctorAbsenceSerializer,
    DoctorSlotsQuerySerializer,
    DoctorSlotsRangeQuerySerializer,
)

from notifications.services.outbox_payload import create_outbox_event


# -----------------------------
# Helpers
# -----------------------------

def _is_admin(user) -> bool:
    return bool(
        getattr(user, "is_staff", False)
        or getattr(user, "is_superuser", False)
        or getattr(user, "role", "") == "admin"
    )


def _create_outbox_event(
    *,
    event_type: str,
    actor,
    recipient,
    obj=None,
    payload=None,
    entity_type: str | None = None,
    entity_id=None,
    route: str | None = None,
    title: str | None = None,
    message: str | None = None,
) -> None:
    """
    Wrapper موحّد (مثل clinical/views.py):
    - يضمن route صحيح مع Flutter الحالي
    - يضمن payload غني مع actor_name/recipient_name تلقائيًا داخل create_outbox_event
    """
    create_outbox_event(
        event_type=event_type,
        actor=actor,
        recipient=recipient,
        obj=obj,
        entity_type=entity_type,
        entity_id=entity_id,
        route=route,
        payload=payload,
        title=title,
        message=message,
    )


class _ImpersonatedRequest:
    """
    Minimal request-like object for serializer context, to ensure validation
    runs against the target doctor (not admin) when admin manages absences.
    """
    def __init__(self, user):
        self.user = user


# -----------------------------
# Doctor search (Authenticated)
# -----------------------------

class DoctorSearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        q = (request.query_params.get("q") or "").strip()
        if not q:
            return Response({"results": []})

        # البحث بالاختصاص
        doctor_ids_by_specialty = DoctorDetails.objects.filter(
            specialty__icontains=q
        ).values_list("user_id", flat=True)

        # جلب الأطباء
        doctors = (
            CustomUser.objects.filter(role="doctor", is_active=True)
            .filter(Q(username__icontains=q) | Q(id__in=doctor_ids_by_specialty))
            .select_related("governorate")
            .order_by("username")[:50]
        )

        # جلب تفاصيل الأطباء
        details_map = {
            row["user_id"]: row
            for row in DoctorDetails.objects.filter(
                user_id__in=[d.id for d in doctors]
            ).values("user_id", "specialty", "experience_years")
        }

        # بناء النتيجة
        results = []
        for d in doctors:
            det = details_map.get(d.id, {})
            results.append(
                {
                    "id": d.id,
                    "username": d.username,
                    "email": d.email,
                    "governorate_id": d.governorate_id,
                    "governorate_name": getattr(d.governorate, "name", None),
                    "specialty": det.get("specialty"),
                    "experience_years": det.get("experience_years"),
                }
            )

        return Response({"results": results})



# -----------------------------
# Doctor visit types (central + specific)
# -----------------------------

class DoctorVisitTypesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        doctor = get_object_or_404(CustomUser, id=doctor_id, role="doctor")

        types = AppointmentType.objects.all().order_by("type_name")

        overrides = {
            row["appointment_type_id"]: row["duration_minutes"]
            for row in DoctorAppointmentType.objects.filter(doctor_id=doctor.id).values(
                "appointment_type_id",
                "duration_minutes",
            )
        }

        central = []
        for t in types:
            default_minutes = int(getattr(t, "default_duration_minutes", 15) or 15)
            resolved = int(overrides.get(t.id, default_minutes))

            central.append(
                {
                    "appointment_type_id": t.id,
                    "type_name": t.type_name,
                    "description": t.description,
                    "resolved_duration_minutes": resolved,
                    "default_duration_minutes": default_minutes,
                    "requires_approved_files": bool(getattr(t, "requires_approved_files", False)),
                    "has_doctor_override": t.id in overrides,
                }
            )

        specific_qs = DoctorSpecificVisitType.objects.filter(
            doctor_id=doctor.id
        ).order_by("name")

        specific = [
            {
                "id": s.id,
                "name": s.name,
                "duration_minutes": s.duration_minutes,
                "description": s.description,
            }
            for s in specific_qs
        ]

        return Response(
            {
                "doctor_id": doctor.id,
                "central": central,
                "specific": specific,
                "specific_booking_enabled": False,
            },
            status=status.HTTP_200_OK,
        )

# -----------------------------
# Create appointment (patient)
# -----------------------------

class AppointmentCreateView(APIView):
    permission_classes = [IsPatient]

    @transaction.atomic
    def post(self, request):
        serializer = AppointmentCreateSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        appointment = serializer.save()

        # -----------------------------
        # Notifications: appointment_created
        # Recipient: doctor
        # IMPORTANT: route must exist in Flutter -> use /app/appointments
        # -----------------------------
        try:
            _create_outbox_event(
                event_type="appointment_created",
                actor=request.user,              # patient
                recipient=appointment.doctor,    # notify doctor
                obj=appointment,
                entity_type="appointment",
                entity_id=appointment.id,
                route="/app/appointments",
                payload={
                    "appointment_id": appointment.id,
                    "status": appointment.status,
                    "patient_id": appointment.patient_id,
                    "doctor_id": appointment.doctor_id,
                    "date_time": appointment.date_time.isoformat() if appointment.date_time else None,
                    "title": "طلب موعد جديد",
                    "message": "تم إنشاء طلب موعد جديد.",
                },
            )
        except Exception:
            pass

        triage = getattr(appointment, "triage", None)

        tz = timezone.get_current_timezone()

        def iso_local(dt):
            if dt is None:
                return None
            if timezone.is_naive(dt):
                dt = timezone.make_aware(dt, tz)
            return dt.astimezone(tz).isoformat()

        return Response(
            {
                "id": appointment.id,
                "patient": appointment.patient_id,
                "doctor": appointment.doctor_id,
                "appointment_type": appointment.appointment_type_id,
                "date_time": iso_local(appointment.date_time),
                "duration_minutes": appointment.duration_minutes,
                "status": appointment.status,
                "notes": appointment.notes,
                "created_at": iso_local(appointment.created_at),
                "triage": (
                    {
                        "id": triage.id,
                        "symptoms_text": triage.symptoms_text,
                        "temperature_c": str(triage.temperature_c) if triage.temperature_c is not None else None,
                        "bp_systolic": triage.bp_systolic,
                        "bp_diastolic": triage.bp_diastolic,
                        "heart_rate": triage.heart_rate,
                        "score": triage.score,
                        "confidence": triage.confidence,
                        "missing_fields": triage.missing_fields,
                        "score_version": triage.score_version,
                        "created_at": iso_local(triage.created_at),
                    }
                    if triage is not None
                    else None
                ),
            },
            status=status.HTTP_201_CREATED,
        )

# -----------------------------
# Doctor actions: mark no_show
# -----------------------------

@api_view(["POST"])
@permission_classes([IsDoctor])
def mark_no_show(request, pk: int):
    user = request.user
    appointment = get_object_or_404(Appointment, pk=pk)

    if appointment.doctor_id != user.id:
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    if appointment.status == "cancelled":
        return Response(
            {"detail": "Cancelled appointments cannot be marked as no_show."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if appointment.status == "no_show":
        return Response({"id": appointment.id, "status": appointment.status}, status=status.HTTP_200_OK)

    if appointment.status != "confirmed":
        return Response(
            {"detail": "Only confirmed appointments can be marked as no_show."},
            status=status.HTTP_409_CONFLICT,
        )

    end_dt = appointment.date_time + timedelta(minutes=appointment.duration_minutes or 0)
    if end_dt > timezone.now():
        return Response(
            {"detail": "Appointment has not ended yet."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    has_orders = ClinicalOrder.objects.filter(appointment_id=appointment.id).exists()
    has_rx = Prescription.objects.filter(appointment_id=appointment.id).exists()
    has_adh = MedicationAdherence.objects.filter(
        prescription_item__prescription__appointment_id=appointment.id
    ).exists()

    if has_orders or has_rx or has_adh:
        return Response(
            {"detail": "Cannot mark no_show after clinical actions were recorded."},
            status=status.HTTP_409_CONFLICT,
        )

    appointment.status = "no_show"
    appointment.save(update_fields=["status", "updated_at"])

    # -----------------------------
    # Notifications: appointment_no_show
    # Recipient: patient
    # IMPORTANT: route must exist -> /app/appointments
    # -----------------------------
    try:
        _create_outbox_event(
            event_type="appointment_no_show",
            actor=request.user,             # doctor
            recipient=appointment.patient,  # patient
            obj=appointment,
            entity_type="appointment",
            entity_id=appointment.id,
            route="/app/appointments",
            payload={
                "appointment_id": appointment.id,
                "status": appointment.status,   # no_show
                "patient_id": appointment.patient_id,
                "doctor_id": appointment.doctor_id,
                "date_time": appointment.date_time.isoformat() if appointment.date_time else None,
                "title": "لم يتم الحضور للموعد",
                "message": "تم وضع الموعد بحالة عدم حضور (No-show).",
            },
        )
    except Exception:
        pass

    return Response({"id": appointment.id, "status": appointment.status}, status=status.HTTP_200_OK)


# -----------------------------
# Cancel appointment (patient/doctor/admin)
# -----------------------------

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def cancel_appointment(request, pk: int):
    user = request.user
    appointment = get_object_or_404(Appointment, pk=pk)

    is_admin_flag = _is_admin(user)
    is_owner_patient = appointment.patient_id == user.id
    is_owner_doctor = appointment.doctor_id == user.id

    if not (is_admin_flag or is_owner_patient or is_owner_doctor):
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

    has_orders = ClinicalOrder.objects.filter(appointment_id=appointment.id).exists()
    has_rx = Prescription.objects.filter(appointment_id=appointment.id).exists()

    if has_orders or has_rx:
        return Response(
            {"detail": "Cannot cancel appointment after clinical actions were recorded."},
            status=status.HTTP_409_CONFLICT,
        )

    appointment.status = "cancelled"
    appointment.save(update_fields=["status", "updated_at"])

    # -----------------------------
    # Notifications: appointment_cancelled
    # recipients = other party (or both if admin)
    # IMPORTANT: route must exist -> /app/appointments
    # -----------------------------
    try:
        actor = request.user

        recipients = []
        if getattr(actor, "role", "") == "patient":
            recipients = [appointment.doctor]
        elif getattr(actor, "role", "") == "doctor":
            recipients = [appointment.patient]
        else:
            recipients = [appointment.patient, appointment.doctor]

        for recipient in recipients:
            _create_outbox_event(
                event_type="appointment_cancelled",
                actor=actor,
                recipient=recipient,
                obj=appointment,
                entity_type="appointment",
                entity_id=appointment.id,
                route="/app/appointments",
                payload={
                    "appointment_id": appointment.id,
                    "status": appointment.status,  # cancelled
                    "cancelled_by_role": getattr(actor, "role", None),
                    "patient_id": appointment.patient_id,
                    "doctor_id": appointment.doctor_id,
                    "date_time": appointment.date_time.isoformat() if appointment.date_time else None,
                    "title": "تم إلغاء الموعد",
                    "message": "تم إلغاء الموعد.",
                },
            )
    except Exception:
        pass

    return Response({"id": appointment.id, "status": appointment.status}, status=status.HTTP_200_OK)


# -----------------------------
# Confirm appointment (doctor/admin)
# -----------------------------

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def confirm_appointment(request, pk: int):
    user = request.user
    appointment = get_object_or_404(Appointment, pk=pk)

    is_admin_flag = _is_admin(user)
    is_owner_doctor = appointment.doctor_id == user.id

    if not (is_admin_flag or is_owner_doctor):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    if appointment.status in ["cancelled", "no_show"]:
        return Response(
            {"detail": "This appointment cannot be confirmed."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if appointment.status == "confirmed":
        return Response(
            {"id": appointment.id, "status": appointment.status},
            status=status.HTTP_200_OK,
        )

    if appointment.status != "pending":
        return Response(
            {"detail": "Only pending appointments can be confirmed."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    appt_type = appointment.appointment_type
    if bool(getattr(appt_type, "requires_approved_files", False)):
        open_orders = ClinicalOrder.objects.filter(
            doctor_id=appointment.doctor_id,
            patient_id=appointment.patient_id,
            status=ClinicalOrder.Status.OPEN,
        ).only("id")

        if open_orders.exists():
            for order in open_orders:
                files_qs = MedicalRecordFile.objects.filter(
                    order_id=order.id,
                    patient_id=appointment.patient_id,
                ).only("id", "review_status")

                if not files_qs.exists():
                    return Response(
                        {
                            "detail": "Cannot confirm follow-up: missing required files.",
                            "order_id": order.id,
                        },
                        status=status.HTTP_409_CONFLICT,
                    )

                if files_qs.exclude(
                    review_status=MedicalRecordFile.ReviewStatus.APPROVED
                ).exists():
                    return Response(
                        {
                            "detail": "Cannot confirm follow-up: some files are not approved yet.",
                            "order_id": order.id,
                        },
                        status=status.HTTP_409_CONFLICT,
                    )

    appointment.status = "confirmed"
    appointment.save(update_fields=["status", "updated_at"])

    # -----------------------------
    # Notifications: appointment_confirmed
    # Recipient: patient
    # IMPORTANT: route must exist -> /app/appointments
    # -----------------------------
    try:
        _create_outbox_event(
            event_type="appointment_confirmed",
            actor=request.user,            # doctor/admin
            recipient=appointment.patient, # patient
            obj=appointment,
            entity_type="appointment",
            entity_id=appointment.id,
            route="/app/appointments",
            payload={
                "appointment_id": appointment.id,
                "status": appointment.status,  # confirmed
                "patient_id": appointment.patient_id,
                "doctor_id": appointment.doctor_id,
                "date_time": appointment.date_time.isoformat() if appointment.date_time else None,
                "title": "تم تأكيد الموعد",
                "message": "تم تأكيد موعدك.",
            },
        )
    except Exception:
        pass

    return Response(
        {"id": appointment.id, "status": appointment.status},
        status=status.HTTP_200_OK,
    )


# -----------------------------
# Slots (single day)
# -----------------------------

class DoctorAvailableSlotsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        qs = DoctorSlotsQuerySerializer(data=request.query_params)
        qs.is_valid(raise_exception=True)
        day_date = qs.validated_data["date"]
        appointment_type_id = qs.validated_data["appointment_type_id"]

        doctor = get_object_or_404(CustomUser, id=doctor_id, role="doctor")
        appt_type = get_object_or_404(AppointmentType, id=appointment_type_id)

        override = DoctorAppointmentType.objects.filter(
            doctor_id=doctor.id,
            appointment_type_id=appt_type.id,
        ).first()

        default_minutes = int(getattr(appt_type, "default_duration_minutes", 15) or 15)
        duration_minutes = int(override.duration_minutes) if override else default_minutes
        if duration_minutes <= 0:
            return Response({"detail": "Invalid duration."}, status=status.HTTP_400_BAD_REQUEST)

        tz = timezone.get_current_timezone()

        day_name = day_date.strftime("%A")
        availability = DoctorAvailability.objects.filter(
            doctor_id=doctor.id,
            day_of_week=day_name,
        ).first()

        if not availability:
            return Response(
                {
                    "doctor_id": doctor.id,
                    "date": day_date.isoformat(),
                    "appointment_type_id": appt_type.id,
                    "duration_minutes": duration_minutes,
                    "availability": None,
                    "slots": [],
                    "timezone": str(tz),
                },
                status=status.HTTP_200_OK,
            )

        start_dt = timezone.make_aware(datetime.combine(day_date, availability.start_time), tz)
        end_dt = timezone.make_aware(datetime.combine(day_date, availability.end_time), tz)

        now_local = timezone.now().astimezone(tz)
        if day_date == now_local.date() and now_local > start_dt:
            start_dt = now_local.replace(second=0, microsecond=0)

        if start_dt >= end_dt:
            return Response(
                {
                    "doctor_id": doctor.id,
                    "date": day_date.isoformat(),
                    "appointment_type_id": appt_type.id,
                    "duration_minutes": duration_minutes,
                    "availability": {
                        "start": availability.start_time.strftime("%H:%M"),
                        "end": availability.end_time.strftime("%H:%M"),
                    },
                    "slots": [],
                    "timezone": str(tz),
                },
                status=status.HTTP_200_OK,
            )

        blocking_statuses = ["pending", "Pending", "confirmed", "Confirmed"]

        existing = Appointment.objects.filter(
            doctor_id=doctor.id,
            status__in=blocking_statuses,
            date_time__lt=end_dt,
            date_time__gte=start_dt - timedelta(days=1),
        ).only("date_time", "duration_minutes")

        intervals = []

        for ap in existing:
            ap_start = ap.date_time
            if timezone.is_naive(ap_start):
                ap_start = timezone.make_aware(ap_start, tz)
            else:
                ap_start = ap_start.astimezone(tz)

            ap_dur = int(ap.duration_minutes or 0) or default_minutes
            ap_end = ap_start + timedelta(minutes=ap_dur)
            intervals.append((ap_start, ap_end))

        absences = DoctorAbsence.objects.filter(
            doctor_id=doctor.id,
            start_time__lt=end_dt,
            end_time__gt=start_dt,
        ).only("start_time", "end_time")

        for ab in absences:
            ab_start = ab.start_time
            ab_end = ab.end_time

            if timezone.is_naive(ab_start):
                ab_start = timezone.make_aware(ab_start, tz)
            else:
                ab_start = ab_start.astimezone(tz)

            if timezone.is_naive(ab_end):
                ab_end = timezone.make_aware(ab_end, tz)
            else:
                ab_end = ab_end.astimezone(tz)

            if ab_start < start_dt:
                ab_start = start_dt
            if ab_end > end_dt:
                ab_end = end_dt

            if ab_start < ab_end:
                intervals.append((ab_start, ab_end))

        intervals.sort(key=lambda x: x[0])

        def find_first_overlap(a_start, a_end):
            for b_start, b_end in intervals:
                if b_start < a_end and a_start < b_end:
                    return (b_start, b_end)
            return None

        slots = []
        step = timedelta(minutes=duration_minutes)
        cursor = start_dt.replace(second=0, microsecond=0)

        while cursor + step <= end_dt:
            candidate_end = cursor + step
            hit = find_first_overlap(cursor, candidate_end)

            if hit is None:
                slots.append(cursor.strftime("%H:%M"))
                cursor = cursor + step
                continue

            _, hit_end = hit
            jump_to = hit_end.replace(second=0, microsecond=0)

            if jump_to <= cursor:
                jump_to = cursor + step

            cursor = jump_to
            if cursor >= end_dt:
                break

        return Response(
            {
                "doctor_id": doctor.id,
                "date": day_date.isoformat(),
                "appointment_type_id": appt_type.id,
                "duration_minutes": duration_minutes,
                "availability": {
                    "start": availability.start_time.strftime("%H:%M"),
                    "end": availability.end_time.strftime("%H:%M"),
                },
                "slots": slots,
                "timezone": str(tz),
            },
            status=status.HTTP_200_OK,
        )


# -----------------------------
# Slots-range (multi-day) with CLAMP
# -----------------------------

class DoctorAvailableSlotsRangeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        qs = DoctorSlotsRangeQuerySerializer(data=request.query_params)
        qs.is_valid(raise_exception=True)
        v = qs.validated_data

        doctor = get_object_or_404(CustomUser, id=doctor_id, role="doctor")
        appt_type = get_object_or_404(AppointmentType, id=v["appointment_type_id"])

        override = DoctorAppointmentType.objects.filter(
            doctor_id=doctor.id,
            appointment_type_id=appt_type.id,
        ).first()

        default_minutes = int(getattr(appt_type, "default_duration_minutes", 15) or 15)
        duration_minutes = int(override.duration_minutes) if override else default_minutes
        if duration_minutes <= 0:
            return Response({"detail": "Invalid duration."}, status=status.HTTP_400_BAD_REQUEST)

        tz = timezone.get_current_timezone()
        now_local = timezone.now().astimezone(tz)

        start_date = v["from_date"]
        end_date = v["to_date"]

        avail_qs = DoctorAvailability.objects.filter(doctor_id=doctor.id).only(
            "day_of_week", "start_time", "end_time"
        )
        availability_by_dayname = {a.day_of_week: a for a in avail_qs}

        blocking_statuses = ["pending", "Pending", "confirmed", "Confirmed"]

        range_start_dt = timezone.make_aware(datetime.combine(start_date, datetime.min.time()), tz)
        range_end_dt = timezone.make_aware(datetime.combine(end_date, datetime.max.time()), tz)

        absences_qs = DoctorAbsence.objects.filter(
            doctor_id=doctor.id,
            start_time__lt=range_end_dt,
            end_time__gt=range_start_dt,
        ).only("start_time", "end_time")

        existing = Appointment.objects.filter(
            doctor_id=doctor.id,
            status__in=blocking_statuses,
            date_time__lt=range_end_dt,
            date_time__gte=range_start_dt - timedelta(days=1),
        ).only("date_time", "duration_minutes")

        intervals_by_date = defaultdict(list)

        for ap in existing:
            ap_start = ap.date_time
            if timezone.is_naive(ap_start):
                ap_start = timezone.make_aware(ap_start, tz)
            else:
                ap_start = ap_start.astimezone(tz)

            ap_dur = int(ap.duration_minutes or 0) or default_minutes
            ap_end = ap_start + timedelta(minutes=ap_dur)

            cur_date = ap_start.date()
            end_touch = ap_end.date()
            while cur_date <= end_touch:
                intervals_by_date[cur_date].append((ap_start, ap_end))
                cur_date = cur_date + timedelta(days=1)

        for ab in absences_qs:
            ab_start = ab.start_time
            ab_end = ab.end_time

            if timezone.is_naive(ab_start):
                ab_start = timezone.make_aware(ab_start, tz)
            else:
                ab_start = ab_start.astimezone(tz)

            if timezone.is_naive(ab_end):
                ab_end = timezone.make_aware(ab_end, tz)
            else:
                ab_end = ab_end.astimezone(tz)

            cur_date = ab_start.date()
            end_touch = ab_end.date()
            while cur_date <= end_touch:
                intervals_by_date[cur_date].append((ab_start, ab_end))
                cur_date = cur_date + timedelta(days=1)

        def compute_day_slots(day_date):
            day_name = day_date.strftime("%A")
            availability = availability_by_dayname.get(day_name)

            if not availability:
                return None

            start_dt = timezone.make_aware(datetime.combine(day_date, availability.start_time), tz)
            end_dt = timezone.make_aware(datetime.combine(day_date, availability.end_time), tz)

            if day_date == now_local.date() and now_local > start_dt:
                start_dt = now_local.replace(second=0, microsecond=0)

            if start_dt >= end_dt:
                return None

            raw_intervals = intervals_by_date.get(day_date, [])
            intervals = []

            for a_start, a_end in raw_intervals:
                if timezone.is_naive(a_start):
                    a_start = timezone.make_aware(a_start, tz)
                else:
                    a_start = a_start.astimezone(tz)

                if timezone.is_naive(a_end):
                    a_end = timezone.make_aware(a_end, tz)
                else:
                    a_end = a_end.astimezone(tz)

                if a_start < start_dt:
                    a_start = start_dt
                if a_end > end_dt:
                    a_end = end_dt

                if a_start < a_end:
                    intervals.append((a_start, a_end))

            intervals.sort(key=lambda x: x[0])

            def find_first_overlap(a_start, a_end):
                for b_start, b_end in intervals:
                    if b_start < a_end and a_start < b_end:
                        return (b_start, b_end)
                return None

            slots = []
            step = timedelta(minutes=duration_minutes)
            cursor = start_dt.replace(second=0, microsecond=0)

            while cursor + step <= end_dt:
                candidate_end = cursor + step
                hit = find_first_overlap(cursor, candidate_end)

                if hit is None:
                    slots.append(cursor.strftime("%H:%M"))
                    cursor = cursor + step
                    continue

                _, hit_end = hit
                jump_to = hit_end.replace(second=0, microsecond=0)

                if jump_to <= cursor:
                    jump_to = cursor + step

                cursor = jump_to
                if cursor >= end_dt:
                    break

            if not slots:
                return None

            return {
                "date": day_date.isoformat(),
                "availability": {
                    "start": availability.start_time.strftime("%H:%M"),
                    "end": availability.end_time.strftime("%H:%M"),
                },
                "slots": slots,
            }

        days_out = []
        d = start_date
        while d <= end_date:
            payload = compute_day_slots(d)
            if payload is not None:
                days_out.append(payload)
            d = d + timedelta(days=1)

        return Response(
            {
                "doctor_id": doctor.id,
                "appointment_type_id": appt_type.id,
                "duration_minutes": duration_minutes,
                "timezone": str(tz),
                "range": {"from": start_date.isoformat(), "to": end_date.isoformat()},
                "days": days_out,
            },
            status=status.HTTP_200_OK,
        )


# -----------------------------
# My appointments (filters: status, preset, time)
# -----------------------------

class MyAppointmentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(user, "role", "")

        qs = Appointment.objects.select_related("appointment_type", "doctor", "patient", "triage")

        if role == "patient":
            qs = qs.filter(patient_id=user.id)
        elif role == "doctor":
            qs = qs.filter(doctor_id=user.id)
        else:
            return Response({"results": []}, status=status.HTTP_200_OK)

        raw_status = (request.query_params.get("status") or "").strip().lower()

        preset = (request.query_params.get("preset") or "").strip().lower()
        preset_day = (request.query_params.get("date") or "").strip()

        date_from = (request.query_params.get("from") or "").strip()
        date_to = (request.query_params.get("to") or "").strip()

        tz = timezone.get_current_timezone()
        now_local = timezone.now().astimezone(tz)

        if raw_status:
            status_map = {
                "pending": ["pending", "Pending"],
                "confirmed": ["confirmed", "Confirmed"],
                "cancelled": ["cancelled", "Cancelled"],
                "no_show": ["no_show"],
            }
            allowed = status_map.get(raw_status)
            if allowed:
                qs = qs.filter(status__in=allowed)
            else:
                qs = qs.none()

        time_filter = (request.query_params.get("time") or "upcoming").strip().lower()
        now_dt = timezone.now()

        if time_filter == "upcoming":
            qs = qs.filter(date_time__gte=now_dt)
        elif time_filter == "past":
            qs = qs.filter(date_time__lt=now_dt)
        elif time_filter == "all":
            pass
        else:
            return Response(
                {"detail": "Invalid time filter. Use time=upcoming|past|all"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        def day_range(d):
            start = timezone.make_aware(datetime.combine(d, datetime.min.time()), tz)
            end = timezone.make_aware(datetime.combine(d, datetime.max.time()), tz)
            return start, end

        if preset == "today":
            d1 = now_local.date()
            start_dt, end_dt = day_range(d1)
            qs = qs.filter(date_time__gte=start_dt, date_time__lte=end_dt)

        elif preset == "next7":
            d1 = now_local.date()
            d2 = (now_local + timedelta(days=7)).date()
            start_dt, _ = day_range(d1)
            _, end_dt = day_range(d2)
            qs = qs.filter(date_time__gte=start_dt, date_time__lte=end_dt)

        elif preset == "day":
            if not preset_day:
                return Response(
                    {"detail": "Missing date. Use ?preset=day&date=YYYY-MM-DD"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            try:
                d1 = datetime.strptime(preset_day, "%Y-%m-%d").date()
            except ValueError:
                return Response(
                    {"detail": "Invalid date. Use YYYY-MM-DD."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            start_dt, end_dt = day_range(d1)
            qs = qs.filter(date_time__gte=start_dt, date_time__lte=end_dt)

        else:
            if date_from:
                try:
                    d1 = datetime.strptime(date_from, "%Y-%m-%d").date()
                except ValueError:
                    return Response(
                        {"detail": "Invalid from date. Use YYYY-MM-DD."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                start_dt, _ = day_range(d1)
                qs = qs.filter(date_time__gte=start_dt)

            if date_to:
                try:
                    d2 = datetime.strptime(date_to, "%Y-%m-%d").date()
                except ValueError:
                    return Response(
                        {"detail": "Invalid to date. Use YYYY-MM-DD."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                _, end_dt = day_range(d2)
                qs = qs.filter(date_time__lte=end_dt)

        qs = qs.order_by("-date_time")[:200]
        appointments_list = list(qs)
        appt_ids = [a.id for a in appointments_list]

        order_rows = ClinicalOrder.objects.filter(
            appointment_id__in=appt_ids
        ).values("appointment_id", "status")

        orders_by_appt = {}
        for row in order_rows:
            aid = row["appointment_id"]
            st = row["status"]
            bucket = orders_by_appt.setdefault(aid, {"any": False, "open": False})
            bucket["any"] = True
            if st == ClinicalOrder.Status.OPEN:
                bucket["open"] = True

        results = []
        for ap in appointments_list:
            flags = orders_by_appt.get(ap.id, {"any": False, "open": False})
            has_any_orders = bool(flags["any"])
            has_open_orders = bool(flags["open"])

            triage_obj = getattr(ap, "triage", None)

            triage_payload = None
            if triage_obj is not None:
                triage_payload = {
                    "symptoms_text": triage_obj.symptoms_text,
                    "temperature_c": str(triage_obj.temperature_c) if triage_obj.temperature_c is not None else None,
                    "bp_systolic": triage_obj.bp_systolic,
                    "bp_diastolic": triage_obj.bp_diastolic,
                    "heart_rate": triage_obj.heart_rate,
                    "score": triage_obj.score,
                    "confidence": triage_obj.confidence,
                    "missing_fields": triage_obj.missing_fields,
                    "score_version": triage_obj.score_version,
                    "created_at": triage_obj.created_at.astimezone(tz).isoformat(),
                }

            results.append(
                {
                    "id": ap.id,
                    "patient": ap.patient_id,
                    "patient_name": getattr(ap.patient, "username", None),
                    "doctor": ap.doctor_id,
                    "doctor_name": getattr(ap.doctor, "username", None),
                    "appointment_type": ap.appointment_type_id,
                    "appointment_type_name": getattr(ap.appointment_type, "type_name", None),
                    "date_time": ap.date_time.astimezone(tz).isoformat(),
                    "duration_minutes": ap.duration_minutes,
                    "status": ap.status,
                    "notes": ap.notes,
                    "created_at": ap.created_at.astimezone(tz).isoformat(),
                    "has_any_orders": has_any_orders,
                    "has_open_orders": has_open_orders,
                    "triage": triage_payload,
                }
            )

        return Response({"results": results}, status=status.HTTP_200_OK)


# -----------------------------
# Doctor Absences (CRUD)
# Admin: manage all; Doctor: manage own
# -----------------------------

class DoctorAbsenceListCreateView(APIView):
    permission_classes = [IsAuthenticated, IsDoctorOrAdmin]

    def get(self, request):
        user = request.user
        is_admin_flag = _is_admin(user)

        qs = DoctorAbsence.objects.all().order_by("-start_time") if is_admin_flag else \
             DoctorAbsence.objects.filter(doctor=user).order_by("-start_time")

        if is_admin_flag:
            raw_doctor_id = (request.query_params.get("doctor_id") or "").strip()
            if raw_doctor_id:
                try:
                    did = int(raw_doctor_id)
                    qs = qs.filter(doctor_id=did)
                except ValueError:
                    return Response(
                        {"detail": "Invalid doctor_id. Use integer."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

        serializer = DoctorAbsenceSerializer(qs, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        user = request.user
        is_admin_flag = _is_admin(user)

        data = request.data.copy()

        if is_admin_flag:
            raw_doctor_id = (data.get("doctor_id") or "").strip()
            if not raw_doctor_id:
                return Response(
                    {"detail": "doctor_id is required for admin."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            try:
                did = int(raw_doctor_id)
            except ValueError:
                return Response({"detail": "Invalid doctor_id."}, status=status.HTTP_400_BAD_REQUEST)

            doctor = get_object_or_404(CustomUser, id=did, role="doctor")

            serializer = DoctorAbsenceSerializer(
                data=data,
                context={"request": _ImpersonatedRequest(doctor)},
            )
            serializer.is_valid(raise_exception=True)
            absence = serializer.save()
            return Response(DoctorAbsenceSerializer(absence).data, status=status.HTTP_201_CREATED)

        serializer = DoctorAbsenceSerializer(
            data=data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        absence = serializer.save()

        return Response(DoctorAbsenceSerializer(absence).data, status=status.HTTP_201_CREATED)


class DoctorAbsenceDetailView(APIView):
    permission_classes = [IsAuthenticated, IsDoctorOrAdmin]

    def get_object(self, request, pk):
        absence = get_object_or_404(DoctorAbsence, pk=pk)

        if _is_admin(request.user):
            return absence

        if absence.doctor_id != request.user.id:
            raise Http404

        return absence

    def _serializer_context_for(self, request, absence: DoctorAbsence):
        if _is_admin(request.user):
            return {"request": _ImpersonatedRequest(absence.doctor)}
        return {"request": request}

    def get(self, request, pk):
        absence = self.get_object(request, pk)
        serializer = DoctorAbsenceSerializer(absence)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, pk):
        absence = self.get_object(request, pk)
        serializer = DoctorAbsenceSerializer(
            absence,
            data=request.data,
            context=self._serializer_context_for(request, absence),
        )
        serializer.is_valid(raise_exception=True)
        absence = serializer.save()
        return Response(DoctorAbsenceSerializer(absence).data, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        absence = self.get_object(request, pk)
        serializer = DoctorAbsenceSerializer(
            absence,
            data=request.data,
            partial=True,
            context=self._serializer_context_for(request, absence),
        )
        serializer.is_valid(raise_exception=True)
        absence = serializer.save()
        return Response(DoctorAbsenceSerializer(absence).data, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        absence = self.get_object(request, pk)
        absence.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
