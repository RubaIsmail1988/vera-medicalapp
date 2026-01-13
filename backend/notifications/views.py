from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DeviceToken
from .serializers import DeviceTokenUpsertSerializer


class DeviceTokenUpsertView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenUpsertSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token = serializer.validated_data["token"]
        device_id = serializer.validated_data.get("device_id") or None

        now = timezone.now()

        obj, created = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                "user": request.user,
                "device_id": device_id,
                "is_active": True,
                "last_seen": now,
            },
        )

        return Response(
            {
                "id": obj.id,
                "token": obj.token,
                "device_id": obj.device_id,
                "is_active": obj.is_active,
                "last_seen": obj.last_seen.isoformat() if obj.last_seen else None,
                "created": created,
            },
            status=status.HTTP_200_OK,
        )
