from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import api_view, permission_classes
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.db.models import Q
from datetime import datetime, timedelta, time
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from clinical.permissions import IsPatient, IsDoctor
from .serializers import AppointmentCreateSerializer, DoctorSlotsQuerySerializer,DoctorSlotsRangeQuerySerializer
from collections import defaultdict
from accounts.models import (
    CustomUser,
    DoctorDetails,
    DoctorAvailability,
    Appointment,
    AppointmentType,
    DoctorAppointmentType,
    DoctorSpecificVisitType,
)


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

        doctor_ids_by_specialty = DoctorDetails.objects.filter(
            Q(specialty__icontains=q)
        ).values_list("user_id", flat=True)

        doctors = (
            CustomUser.objects.filter(role="doctor")
            .filter(Q(username__icontains=q) | Q(id__in=doctor_ids_by_specialty))
            .order_by("username")[:50]
        )

        # Fetch specialties in one query
        specialties_map = {
            row["user_id"]: row["specialty"]
            for row in DoctorDetails.objects.filter(user_id__in=[d.id for d in doctors]).values("user_id", "specialty")
        }

        results = [
            {
                "id": d.id,
                "username": d.username,
                "email": d.email,
                "specialty": specialties_map.get(d.id),
            }
            for d in doctors
        ]

        return Response({"results": results})


class DoctorVisitTypesView(APIView):
    """
    Read-only endpoint for booking UI:
    - central: all AppointmentType with resolved duration for this doctor
      (DoctorAppointmentType override OR AppointmentType.default_duration_minutes)
    - specific: DoctorSpecificVisitType list for this doctor
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        doctor = get_object_or_404(CustomUser, id=doctor_id, role="doctor")

        # Central catalog
        types = AppointmentType.objects.all().order_by("type_name")

        # Overrides by this doctor
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

        # Doctor-specific types
        specific_qs = DoctorSpecificVisitType.objects.filter(doctor_id=doctor.id).order_by("name")
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
                "specific_booking_enabled": False,  # Contract: booking central only for now

            },
            status=status.HTTP_200_OK,
        )


from django.utils import timezone

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

    # New: prevent future no_show
    end_dt = appointment.date_time + timedelta(minutes=appointment.duration_minutes or 0)

    if end_dt > timezone.now():
        return Response(
            {"detail": "Appointment has not ended yet."},
            status=status.HTTP_400_BAD_REQUEST,
        )


    appointment.status = "no_show"
    appointment.save(update_fields=["status", "updated_at"])

    return Response({"id": appointment.id, "status": appointment.status}, status=status.HTTP_200_OK)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def cancel_appointment(request, pk: int):
    user = request.user
    appointment = get_object_or_404(Appointment, pk=pk)

    is_admin = bool(
        getattr(user, "is_staff", False)
        or getattr(user, "is_superuser", False)
        or getattr(user, "role", "") == "admin"
    )
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

class DoctorAvailableSlotsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        qs = DoctorSlotsQuerySerializer(data=request.query_params)
        qs.is_valid(raise_exception=True)
        day_date = qs.validated_data["date"]
        appointment_type_id = qs.validated_data["appointment_type_id"]

        doctor = get_object_or_404(CustomUser, id=doctor_id, role="doctor")
        appt_type = get_object_or_404(AppointmentType, id=appointment_type_id)

        # Resolve duration
        override = DoctorAppointmentType.objects.filter(
            doctor_id=doctor.id,
            appointment_type_id=appt_type.id,
        ).first()

        default_minutes = int(getattr(appt_type, "default_duration_minutes", 15) or 15)
        duration_minutes = int(override.duration_minutes) if override else default_minutes
        if duration_minutes <= 0:
            return Response({"detail": "Invalid duration."}, status=status.HTTP_400_BAD_REQUEST)

        tz = timezone.get_current_timezone()

        # Availability for that weekday
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

        # today: don't show past
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

        # Prefetch blocking appointments
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

            # jump exactly to end of overlapping appointment (NO grid re-alignment)
            _, hit_end = hit
            jump_to = hit_end.replace(second=0, microsecond=0)

            # safety: ensure forward progress
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


class DoctorAvailableSlotsRangeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        qs = DoctorSlotsRangeQuerySerializer(data=request.query_params)
        qs.is_valid(raise_exception=True)
        v = qs.validated_data

        doctor = get_object_or_404(CustomUser, id=doctor_id, role="doctor")
        appt_type = get_object_or_404(AppointmentType, id=v["appointment_type_id"])

        # Resolve duration
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

        # --------- Prefetch availabilities once ----------
        avail_qs = DoctorAvailability.objects.filter(doctor_id=doctor.id).only(
            "day_of_week", "start_time", "end_time"
        )
        availability_by_dayname = {a.day_of_week: a for a in avail_qs}

        # --------- Prefetch blocking appointments once ----------
        blocking_statuses = ["pending", "Pending", "confirmed", "Confirmed"]

        range_start_dt = timezone.make_aware(datetime.combine(start_date, datetime.min.time()), tz)
        range_end_dt = timezone.make_aware(datetime.combine(end_date, datetime.max.time()), tz)

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

            intervals = intervals_by_date.get(day_date, [])
            intervals = sorted(intervals, key=lambda x: x[0])

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
                return None  # requirement: only days with slots

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

    
class MyAppointmentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(user, "role", "")

        qs = Appointment.objects.select_related("appointment_type", "doctor", "patient")

        if role == "patient":
            qs = qs.filter(patient_id=user.id)
        elif role == "doctor":
            qs = qs.filter(doctor_id=user.id)
        else:
            return Response({"results": []}, status=status.HTTP_200_OK)

        # ---------------- Optional filters ----------------
        raw_status = (request.query_params.get("status") or "").strip().lower()

        # New: preset filters
        preset = (request.query_params.get("preset") or "").strip().lower()  # today | next7 | day
        preset_day = (request.query_params.get("date") or "").strip()        # YYYY-MM-DD (when preset=day)

        # Old: explicit range filters
        date_from = (request.query_params.get("from") or "").strip()
        date_to = (request.query_params.get("to") or "").strip()

        tz = timezone.get_current_timezone()
        now_local = timezone.now().astimezone(tz)

        # ---- status filter (accept legacy variants too) ----
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


        # ---- preset takes precedence over from/to ----
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
            # from/to only if no preset
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

        results = []
        for ap in qs:
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
                }
            )

        return Response({"results": results}, status=status.HTTP_200_OK)
    
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def confirm_appointment(request, pk: int):
    user = request.user
    appointment = get_object_or_404(Appointment, pk=pk)

    is_admin = bool(
        getattr(user, "is_staff", False)
        or getattr(user, "is_superuser", False)
        or getattr(user, "role", "") == "admin"
    )

    is_owner_doctor = appointment.doctor_id == user.id

    # فقط صاحب الموعد (الطبيب) أو Admin
    if not (is_admin or is_owner_doctor):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    # ممنوع تأكيد موعد ملغي أو no_show
    if appointment.status in ["cancelled", "no_show"]:
        return Response(
            {"detail": "This appointment cannot be confirmed."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # idempotent إذا كان confirmed
    if appointment.status == "confirmed":
        return Response(
            {"id": appointment.id, "status": appointment.status},
            status=status.HTTP_200_OK,
        )

    # فقط من pending إلى confirmed
    if appointment.status != "pending":
        return Response(
            {"detail": "Only pending appointments can be confirmed."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    appointment.status = "confirmed"
    appointment.save(update_fields=["status", "updated_at"])

    return Response(
        {"id": appointment.id, "status": appointment.status},
        status=status.HTTP_200_OK,
    )
