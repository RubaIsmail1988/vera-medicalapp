from rest_framework import serializers


class DeviceTokenUpsertSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)
    device_id = serializers.CharField(max_length=128, required=False, allow_blank=True)

    def validate_token(self, value: str) -> str:
        v = (value or "").strip()
        if not v:
            raise serializers.ValidationError("token is required.")
        return v

    def validate_device_id(self, value: str) -> str:
        return (value or "").strip()
