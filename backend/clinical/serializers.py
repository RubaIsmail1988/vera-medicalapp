from rest_framework import serializers
from django.utils import timezone
from .models import (
    ClinicalOrder,
    MedicalRecordFile,
    Prescription,
    PrescriptionItem,
    MedicationAdherence,
    OutboxEvent,
)


# ---------------------------------------------------------------------------
# Clinical Orders
# ---------------------------------------------------------------------------

class ClinicalOrderSerializer(serializers.ModelSerializer):
    doctor_display_name = serializers.SerializerMethodField()
    patient_display_name = serializers.SerializerMethodField()

    class Meta:
        model = ClinicalOrder
        fields = [
            "id",
            "doctor",
            "doctor_display_name",
            "patient",
            "patient_display_name",
            "order_category",
            "title",
            "details",
            "status",
            "appointment",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at", "doctor", "patient"]
        extra_kwargs = {
            "appointment": {"required": True},
        }

    # -------------------------
    # Display helpers
    # -------------------------

    def get_doctor_display_name(self, obj):
        doctor = obj.doctor
        if not doctor:
            return None
        if callable(getattr(doctor, "get_full_name", None)) and doctor.get_full_name():
            return doctor.get_full_name()
        return getattr(doctor, "username", None) or getattr(doctor, "email", None)

    def get_patient_display_name(self, obj):
        patient = obj.patient
        if not patient:
            return None
        if callable(getattr(patient, "get_full_name", None)) and patient.get_full_name():
            return patient.get_full_name()
        return getattr(patient, "username", None) or getattr(patient, "email", None)

    # -------------------------
    # Validation
    # -------------------------

    def validate(self, attrs):
        #  ممنوع إرسال patient من الـ client
        if "patient" in getattr(self, "initial_data", {}) and not self.context.get("patient_from_appointment"):
            raise serializers.ValidationError(
                {"patient": "Do not send patient. It is derived from appointment."}
            )


        appointment = attrs.get("appointment")
        if appointment is None:
            raise serializers.ValidationError({"appointment": "appointment is required."})

        # اشتقاق المريض من الموعد
        ap_patient = getattr(appointment, "patient", None)
        if ap_patient is None:
            raise serializers.ValidationError(
                {"appointment": "appointment has no patient."}
            )

        attrs["patient"] = ap_patient
        return attrs


# ---------------------------------------------------------------------------
# Medical Record Files
# ---------------------------------------------------------------------------

class MedicalRecordFileCreateSerializer(serializers.ModelSerializer):
    """
    مخصص للرفع (multipart): file مطلوب.
    """
    class Meta:
        model = MedicalRecordFile
        fields = [
            "id",
            "order",
            "patient",
            "file",
            "original_filename",
            "review_status",
            "doctor_note",
            "reviewed_by",
            "reviewed_at",
            "uploaded_at",
        ]
        read_only_fields = [
            "id",
            "review_status",
            "doctor_note",
            "reviewed_by",
            "reviewed_at",
            "uploaded_at",
        ]

    def validate(self, attrs):
        order = attrs.get("order")
        patient = attrs.get("patient")
        if order and patient and order.patient_id != patient.id:
            raise serializers.ValidationError(
                {"patient": "Patient must match the patient on the linked ClinicalOrder."}
            )
        return attrs

    def create(self, validated_data):
        f = validated_data.get("file")
        if f and not validated_data.get("original_filename"):
            validated_data["original_filename"] = getattr(f, "name", "")
        return super().create(validated_data)


class MedicalRecordFileSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicalRecordFile
        fields = [
            "id",
            "order",
            "patient",
            "file",
            "original_filename",
            "review_status",
            "doctor_note",
            "reviewed_by",
            "reviewed_at",
            "uploaded_at",
        ]
        read_only_fields = ["id", "uploaded_at"]


# ---------------------------------------------------------------------------
# Prescriptions
# ---------------------------------------------------------------------------

class PrescriptionItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionItem
        fields = [
            "id",
            "medicine_name",
            "dosage",
            "frequency",
            "start_date",
            "end_date",
            "instructions",
        ]
        read_only_fields = ["id"]


class PrescriptionSerializer(serializers.ModelSerializer):
    items = PrescriptionItemSerializer(many=True)
    doctor_display_name = serializers.SerializerMethodField()
    patient_display_name = serializers.SerializerMethodField()

    class Meta:
        model = Prescription
        fields = [
            "id",
            "doctor",
            "doctor_display_name",
            "patient",
            "patient_display_name",
            "appointment",
            "notes",
            "created_at",
            "items",
        ]
        read_only_fields = ["id", "created_at", "doctor"]

    def get_doctor_display_name(self, obj):
        doctor = obj.doctor
        if not doctor:
            return None

        full_name = getattr(doctor, "get_full_name", None)
        if callable(full_name) and full_name():
            return full_name()

        if getattr(doctor, "username", None):
            return doctor.username

        if getattr(doctor, "email", None):
            return doctor.email

        return f"Doctor #{doctor.id}"

    def get_patient_display_name(self, obj):
        patient = obj.patient
        if not patient:
            return None

        full_name = getattr(patient, "get_full_name", None)
        if callable(full_name) and full_name():
            return full_name()

        if getattr(patient, "username", None):
            return patient.username

        if getattr(patient, "email", None):
            return patient.email

        return f"Patient #{patient.id}"

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])
        prescription = Prescription.objects.create(**validated_data)

        items = [
            PrescriptionItem(prescription=prescription, **item_data)
            for item_data in items_data
        ]
        if items:
            PrescriptionItem.objects.bulk_create(items)

        return prescription

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if items_data is not None:
            instance.items.all().delete()
            items = [
                PrescriptionItem(prescription=instance, **item_data)
                for item_data in items_data
            ]
            if items:
                PrescriptionItem.objects.bulk_create(items)

        return instance

    def validate(self, attrs):
        appointment = attrs.get("appointment")
        if appointment is None:
            raise serializers.ValidationError({"appointment": "appointment is required."})

        # allow patient ONLY if injected by server
        if "patient" in attrs and not self.context.get("patient_from_appointment"):
            raise serializers.ValidationError({
                "patient": "Do not send patient. It is derived from appointment."
            })

        return attrs



# ---------------------------------------------------------------------------
# Medication Adherence
# ---------------------------------------------------------------------------

class MedicationAdherenceSerializer(serializers.ModelSerializer):
    # --- حقول مشتقة للعرض فقط ---
    medicine_name = serializers.SerializerMethodField()
    dosage = serializers.SerializerMethodField()
    frequency = serializers.SerializerMethodField()
    patient_display_name = serializers.SerializerMethodField()

    # --- NEW: لتمكين فلتر appointment في Flutter ---
    appointment_id = serializers.SerializerMethodField()
    prescription_id = serializers.SerializerMethodField()

    class Meta:
        model = MedicationAdherence
        fields = [
            "id",
            "patient",
            "patient_display_name",
            "prescription_item",
            "prescription_id",   # NEW
            "appointment_id",    # NEW
            "medicine_name",
            "dosage",
            "frequency",
            "status",
            "taken_at",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "patient",
            "patient_display_name",
            "medicine_name",
            "dosage",
            "frequency",
            "prescription_id",
            "appointment_id",
        ]

    # ----------------------------
    # Serializer methods
    # ----------------------------

    def _rx(self, obj):
        item = getattr(obj, "prescription_item", None)
        return getattr(item, "prescription", None)

    def get_prescription_id(self, obj):
        rx = self._rx(obj)
        return getattr(rx, "id", None)

    def get_appointment_id(self, obj):
        rx = self._rx(obj)
        return getattr(rx, "appointment_id", None)

    def get_medicine_name(self, obj):
        item = getattr(obj, "prescription_item", None)
        return getattr(item, "medicine_name", None)

    def get_dosage(self, obj):
        item = getattr(obj, "prescription_item", None)
        return getattr(item, "dosage", None)

    def get_frequency(self, obj):
        item = getattr(obj, "prescription_item", None)
        return getattr(item, "frequency", None)

    def get_patient_display_name(self, obj):
        patient = getattr(obj, "patient", None)
        if not patient:
            return None

        full_name = getattr(patient, "get_full_name", None)
        if callable(full_name) and full_name():
            return full_name()

        if getattr(patient, "username", None):
            return patient.username

        if getattr(patient, "email", None):
            return patient.email

        return f"Patient #{patient.id}"

    def validate(self, attrs):
        """
        Fix (D-2.5): منع المريض من تسجيل adherence لعنصر لا يخصه.
        - المريض الحالي يجب أن يطابق prescription_item.prescription.patient
        """
        request = self.context.get("request")
        user = getattr(request, "user", None)

        # admin bypass
        if user and getattr(user, "is_authenticated", False):
            if (
                getattr(user, "is_staff", False)
                or getattr(user, "is_superuser", False)
                or getattr(user, "role", "") == "admin"
            ):
                return attrs

        item = attrs.get("prescription_item")
        if not item:
            raise serializers.ValidationError({"prescription_item": "This field is required."})

        rx = getattr(item, "prescription", None)
        rx_patient_id = getattr(rx, "patient_id", None)

        if not user or not getattr(user, "is_authenticated", False):
            raise serializers.ValidationError({"detail": "Authentication required."})

        if rx_patient_id != user.id:
            raise serializers.ValidationError({"detail": "Not found."})

        taken_at = attrs.get("taken_at")
        if taken_at and taken_at > timezone.now():
            raise serializers.ValidationError({"taken_at": "taken_at cannot be in the future."})

        return attrs

# ---------------------------------------------------------------------------
# Outbox
# ---------------------------------------------------------------------------

class OutboxEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = OutboxEvent
        fields = [
            "id",
            "event_type",
            "actor",
            "patient",
            "object_id",
            "payload",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "status", "created_at"]
