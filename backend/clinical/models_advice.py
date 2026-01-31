from django.db import models
from django.conf import settings

class AdviceRun(models.Model):
    patient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="advice_runs")
    engine = models.CharField(max_length=10)  # "rules" | "ml"
    model_version = models.CharField(max_length=50, blank=True, null=True)
    features_snapshot = models.JSONField()
    outputs = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)

class AdviceFeedback(models.Model):
    patient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="advice_feedbacks")
    advice_key = models.CharField(max_length=64)
    helpful = models.BooleanField(default=False)
    dismissed = models.BooleanField(default=False)
    rating = models.PositiveSmallIntegerField(blank=True, null=True)  # 1..5 optional
    created_at = models.DateTimeField(auto_now_add=True)
