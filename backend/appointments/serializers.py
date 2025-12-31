from datetime import timedelta
from datetime import date as date_cls
from django.utils import timezone
from rest_framework import serializers

from accounts.models import (
    Appointment,
    AppointmentType,
    DoctorAvailability,
    DoctorAppointmentType,
    CustomUser,
)

from clinical.models import ClinicalOrder, MedicalRecordFile


class AppointmentCreateSerializer(serializers.Serializer):
    doctor_id = serializers.IntegerField()
    appointment_type_id = serializers.IntegerField()  # REQUIRED (central only)
    date_time = serializers.DateTimeField()
    notes = serializers.CharField(required=False, allow_blank=True)

    # If sent by mistake, we will reject it explicitly (future feature).
    doctor_specific_visit_type_id = serializers.IntegerField(required=False)

    def validate(self, attrs):
        request = self.context["request"]
        patient = request.user

        # 1) Role check (patient only)
        if getattr(patient, "role", "") != "patient":
            raise serializers.ValidationError({"detail": "Only patients can book appointments."})

        # 2) Doctor exists + is doctor
        doctor_id = attrs["doctor_id"]
        try:
            doctor = CustomUser.objects.get(id=doctor_id, role="doctor")
        except CustomUser.DoesNotExist:
            raise serializers.ValidationError({"doctor_id": "Doctor not found."})

        # 3) Reject doctor-specific booking for now (keep model for future)
        if attrs.get("doctor_specific_visit_type_id"):
            raise serializers.ValidationError(
                {
                    "doctor_specific_visit_type_id": (
                        "Doctor-specific visit types are temporarily disabled. "
                        "Please book using appointment_type_id."
                    )
                }
            )

        # 4) Normalize date_time to aware (current tz)
        tz = timezone.get_current_timezone()
        start_dt = attrs["date_time"]
        if timezone.is_naive(start_dt):
            start_dt = timezone.make_aware(start_dt, tz)
        else:
            start_dt = start_dt.astimezone(tz)
        attrs["date_time"] = start_dt

        # 5) Resolve AppointmentType + duration (Doctor override > default 15)
        appointment_type_id = attrs["appointment_type_id"]
        try:
            appt_type = AppointmentType.objects.get(id=appointment_type_id)
        except AppointmentType.DoesNotExist:
            raise serializers.ValidationError({"appointment_type_id": "AppointmentType not found."})

        dat = DoctorAppointmentType.objects.filter(
            doctor=doctor,
            appointment_type=appt_type,
        ).first()

        if dat:
            duration_minutes = dat.duration_minutes
        else:
            duration_minutes = getattr(appt_type, "default_duration_minutes", None)

        if not duration_minutes or int(duration_minutes) <= 0:
            raise serializers.ValidationError({"detail": "Invalid duration."})

        duration_minutes = int(duration_minutes)
        end_dt = start_dt + timedelta(minutes=duration_minutes)

        requires_approved_files = bool(getattr(appt_type, "requires_approved_files", False))

        # 6) Availability check (single window per day)
        day_name = start_dt.strftime("%A")  # Monday..Sunday
        availability = DoctorAvailability.objects.filter(
            doctor=doctor,
            day_of_week=day_name,
        ).first()

        if not availability:
            raise serializers.ValidationError({"detail": "Doctor is not available on this day."})

        start_t = start_dt.timetz().replace(tzinfo=None)
        end_t = end_dt.timetz().replace(tzinfo=None)

        if not (availability.start_time <= start_t < availability.end_time):
            raise serializers.ValidationError({"detail": "Appointment start time is outside doctor availability."})

        if end_t > availability.end_time:
            raise serializers.ValidationError({"detail": "Appointment exceeds doctor availability window."})

        # 7) Overlap check (pending/confirmed block time) + handle legacy capitalized values
        blocking_statuses = ["pending", "confirmed", "Pending", "Confirmed"]

        # نجيب أي موعد ممكن يتقاطع مع [start_dt, end_dt)
        # شرط البداية: ap.date_time < end_dt
        # وشرط النهاية: ap_end > start_dt  (هذا ما سنفحصه في الحلقة)
        # لكن لتقليل البيانات: نأخذ فقط مواعيد تبدأ قبل end_dt
        # ونأخذ مواعيد تبدأ بعد (start_dt - max_duration_safety)
        # بدل 8 ساعات: نستخدم 1 يوم كـ buffer آمن وبسيط مثل slots-range
        window_start = start_dt - timedelta(days=1)
        window_end = end_dt

        candidates = Appointment.objects.filter(
            doctor=doctor,
            status__in=blocking_statuses,
            date_time__lt=window_end,
            date_time__gte=window_start,
        ).only("date_time", "duration_minutes")

        for ap in candidates:
            ap_start = ap.date_time
            if timezone.is_naive(ap_start):
                ap_start = timezone.make_aware(ap_start, tz)
            else:
                ap_start = ap_start.astimezone(tz)

            ap_dur = int(ap.duration_minutes or 0) or duration_minutes
            ap_end = ap_start + timedelta(minutes=ap_dur)

            # [start, end) overlap
            if ap_start < end_dt and start_dt < ap_end:
                raise serializers.ValidationError({"detail": "This time slot is already booked."})


        # 8) Follow-up gate (requires approved files)
        if requires_approved_files:
            open_orders = ClinicalOrder.objects.filter(
                doctor=doctor,
                patient=patient,
                status=ClinicalOrder.Status.OPEN,
            )

            if not open_orders.exists():
                raise serializers.ValidationError(
                    {"detail": "Follow-up booking is blocked until required files are approved."}
                )

            for order in open_orders:
                files = MedicalRecordFile.objects.filter(order=order, patient=patient)
                if not files.exists():
                    raise serializers.ValidationError(
                        {"detail": "Follow-up booking is blocked until required files are approved."}
                    )

                if files.exclude(review_status=MedicalRecordFile.ReviewStatus.APPROVED).exists():
                    raise serializers.ValidationError(
                        {"detail": "Follow-up booking is blocked until required files are approved."}
                    )

        attrs["doctor_obj"] = doctor
        attrs["appointment_type_obj"] = appt_type
        attrs["duration_minutes"] = duration_minutes
        attrs["requires_approved_files"] = requires_approved_files
        return attrs

    def create(self, validated_data):
        patient = self.context["request"].user
        doctor = validated_data["doctor_obj"]
        appt_type = validated_data["appointment_type_obj"]
        start_dt = validated_data["date_time"]

        appointment = Appointment.objects.create(
            patient=patient,
            doctor=doctor,
            appointment_type=appt_type,
            date_time=start_dt,
            duration_minutes=validated_data["duration_minutes"],
            status="pending",
            notes=validated_data.get("notes", ""),
        )
        return appointment


class DoctorSlotsQuerySerializer(serializers.Serializer):
    date = serializers.DateField()
    appointment_type_id = serializers.IntegerField(min_value=1)


class DoctorSlotsRangeQuerySerializer(serializers.Serializer):
    appointment_type_id = serializers.IntegerField(min_value=1)

    from_date = serializers.DateField(required=False)
    to_date = serializers.DateField(required=False)

    days = serializers.IntegerField(required=False, min_value=1, max_value=31)

    MAX_RANGE_DAYS = 31  # keep consistent with days max

    def validate(self, attrs):
        f = attrs.get("from_date")
        t = attrs.get("to_date")
        days = attrs.get("days")

        if days is None and (f is None or t is None):
            raise serializers.ValidationError(
                "Provide either days or (from_date and to_date)."
            )

        if days is not None and (f is not None or t is not None):
            raise serializers.ValidationError(
                "Use either days or from/to, not both."
            )

        if days is None:
            if f > t:
                raise serializers.ValidationError("from_date must be <= to_date.")

            span_days = (t - f).days + 1
            if span_days < 1:
                raise serializers.ValidationError("Invalid date range.")
            if span_days > self.MAX_RANGE_DAYS:
                raise serializers.ValidationError(
                    f"Date range is too large. Max {self.MAX_RANGE_DAYS} days."
                )
            return attrs

        today = timezone.localdate()
        f2 = today
        t2 = today + timedelta(days=int(days) - 1)

        attrs["from_date"] = f2
        attrs["to_date"] = t2
        return attrs
