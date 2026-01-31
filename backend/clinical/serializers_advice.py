from rest_framework import serializers
from .models_advice import AdviceRun, AdviceFeedback

class AdviceRunSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdviceRun
        fields = "__all__"

class AdviceFeedbackSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdviceFeedback
        fields = "__all__"
