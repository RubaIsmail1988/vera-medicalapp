from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from accounts.models import (
    Appointment,
    AppointmentType,
    DoctorAvailability,
    DoctorAppointmentType,
    DoctorSpecificVisitType,
    CustomUser,
)

from clinical.models import ClinicalOrder, MedicalRecordFile


class AppointmentCreateSerializer(serializers.Serializer):
    doctor_id = serializers.IntegerField()
    date_time = serializers.DateTimeField()
    notes = serializers.CharField(required=False, allow_blank=True)

    # exactly one of the following:
    appointment_type_id = serializers.IntegerField(required=False)
    doctor_specific_visit_type_id = serializers.IntegerField(required=False)

    def validate(self, attrs):
        request = self.context["request"]
        patient = request.user

        # 1) role check (patient only)
        if getattr(patient, "role", "") != "patient":
            raise serializers.ValidationError({"detail": "Only patients can book appointments."})

        # 2) doctor exists + is doctor
        doctor_id = attrs["doctor_id"]
        try:
            doctor = CustomUser.objects.get(id=doctor_id, role="doctor")
        except CustomUser.DoesNotExist:
            raise serializers.ValidationError({"doctor_id": "Doctor not found."})

        # 3) exactly one visit type selector
        appointment_type_id = attrs.get("appointment_type_id")
        doctor_specific_id = attrs.get("doctor_specific_visit_type_id")
        if bool(appointment_type_id) == bool(doctor_specific_id):
            raise serializers.ValidationError(
                {"detail": "Provide exactly one of appointment_type_id or doctor_specific_visit_type_id."}
            )

        start_dt = attrs["date_time"]
        if timezone.is_naive(start_dt):
            # keep consistent: treat as server timezone
            start_dt = timezone.make_aware(start_dt, timezone.get_current_timezone())
        attrs["date_time"] = start_dt

        # 4) resolve duration + follow-up gate flag
        requires_approved_files = False
        duration_minutes = None

        if appointment_type_id:
            try:
                appt_type = AppointmentType.objects.get(id=appointment_type_id)
            except AppointmentType.DoesNotExist:
                raise serializers.ValidationError({"appointment_type_id": "AppointmentType not found."})

            # Decision: DoctorAppointmentType > AppointmentType.default_duration_minutes
            # (Field default_duration_minutes will be added in a later commit; for now we enforce that doctor config exists.)
            dat = DoctorAppointmentType.objects.filter(doctor=doctor, appointment_type=appt_type).first()
            if dat:
                duration_minutes = dat.duration_minutes
            else:
                # temporary behavior until default_duration_minutes is added:
                raise serializers.ValidationError(
                    {"appointment_type_id": "This visit type is not configured for this doctor yet."}
                )

            # requires_approved_files will be added later; for now treat as False
            requires_approved_files = False

            attrs["appointment_type_obj"] = appt_type

        else:
            # DoctorSpecificVisitType path
            try:
                v = DoctorSpecificVisitType.objects.get(id=doctor_specific_id, doctor=doctor)
            except DoctorSpecificVisitType.DoesNotExist:
                raise serializers.ValidationError({"doctor_specific_visit_type_id": "Visit type not found for this doctor."})

            duration_minutes = v.duration_minutes
            # no follow-up rule attached here in MVP unless you decide otherwise
            requires_approved_files = False

            # For DB compatibility: Appointment requires appointment_type FK.
            # We map doctor-specific visit to an AppointmentType later (in a later commit).
            raise serializers.ValidationError(
                {"doctor_specific_visit_type_id": "Doctor-specific booking will be enabled after AppointmentType mapping is implemented."}
            )

        if not duration_minutes or duration_minutes <= 0:
            raise serializers.ValidationError({"detail": "Invalid duration."})

        end_dt = start_dt + timedelta(minutes=duration_minutes)

        # 5) availability check (single window per day)
        day_name = start_dt.strftime("%A")  # Monday..Sunday
        availability = DoctorAvailability.objects.filter(doctor=doctor, day_of_week=day_name).first()
        if not availability:
            raise serializers.ValidationError({"detail": "Doctor is not available on this day."})

        start_t = start_dt.timetz().replace(tzinfo=None)
        end_t = end_dt.timetz().replace(tzinfo=None)

        if not (availability.start_time <= start_t < availability.end_time):
            raise serializers.ValidationError({"detail": "Appointment start time is outside doctor availability."})

        if end_t > availability.end_time:
            raise serializers.ValidationError({"detail": "Appointment exceeds doctor availability window."})

        # 6) overlap check (pending/confirmed block time)
        existing = Appointment.objects.filter(
            doctor=doctor,
            status__in=["Pending", "Confirmed"],
        )

        for ap in existing:
            ap_start = ap.date_time
            ap_dur = ap.duration_minutes or 0
            ap_end = ap_start + timedelta(minutes=ap_dur)

            if ap_start < end_dt and start_dt < ap_end:
                raise serializers.ValidationError({"detail": "This time slot is already booked."})

        # 7) follow-up gate (will be enabled later when requires_approved_files exists)
        if requires_approved_files:
            open_orders = ClinicalOrder.objects.filter(doctor=doctor, patient=patient, status=ClinicalOrder.Status.OPEN)
            if not open_orders.exists():
                raise serializers.ValidationError({"detail": "Follow-up booking is blocked until required files are approved."})

            for order in open_orders:
                files = MedicalRecordFile.objects.filter(order=order, patient=patient)
                if not files.exists():
                    raise serializers.ValidationError({"detail": "Follow-up booking is blocked until required files are approved."})
                if files.exclude(review_status=MedicalRecordFile.ReviewStatus.APPROVED).exists():
                    raise serializers.ValidationError({"detail": "Follow-up booking is blocked until required files are approved."})

        attrs["doctor_obj"] = doctor
        attrs["duration_minutes"] = duration_minutes
        return attrs

    def create(self, validated_data):
        patient = self.context["request"].user
        doctor = validated_data["doctor_obj"]
        appt_type = validated_data.get("appointment_type_obj")
        start_dt = validated_data["date_time"]

        appointment = Appointment.objects.create(
            patient=patient,
            doctor=doctor,
            appointment_type=appt_type,
            date_time=start_dt,
            duration_minutes=validated_data["duration_minutes"],
            status="Pending",
            notes=validated_data.get("notes", ""),
        )
        return appointment
