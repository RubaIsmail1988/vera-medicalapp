from rest_framework import serializers

from .models import (
    ClinicalOrder,
    MedicalRecordFile,
    Prescription,
    PrescriptionItem,
    MedicationAdherence,
    OutboxEvent,
)


class ClinicalOrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClinicalOrder
        fields = [
            "id",
            "doctor",
            "patient",
            "order_category",
            "title",
            "details",
            "status",
            "appointment",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


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
        # لا ندخل هنا منطق صلاحيات (Doctor/Patient) لأنه مكانه views/permissions.
        # فقط تحقق سلامة ربط الملف بطلب.
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

    class Meta:
        model = Prescription
        fields = [
            "id",
            "doctor",
            "patient",
            "appointment",
            "notes",
            "created_at",
            "items",
        ]
        read_only_fields = ["id", "created_at"]

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
        # تحديث بسيط: إذا أُرسلت items نستبدلها بالكامل (بدون ذكاء/دمج).
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


class MedicationAdherenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicationAdherence
        fields = [
            "id",
            "patient",
            "prescription_item",
            "status",
            "taken_at",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]


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
