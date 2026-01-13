from django.conf import settings
from django.db import models
from django.utils import timezone


class DeviceToken(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="device_tokens",
    )

    token = models.CharField(max_length=255, unique=True)
    is_active = models.BooleanField(default=True)

    device_id = models.CharField(max_length=128, blank=True, null=True)

    created_at = models.DateTimeField(default=timezone.now)
    last_seen = models.DateTimeField(blank=True, null=True)

    class Meta:
        ordering = ["-last_seen", "-created_at"]

    def __str__(self) -> str:
        return f"{self.user_id} - {self.token[:12]}..."
