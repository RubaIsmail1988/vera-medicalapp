from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from accounts.models import PatientDetails
from clinical.advice.factory import get_advice_engine

class PatientAdviceCardsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, user_id: int):
        try:
            pd = PatientDetails.objects.get(user_id=user_id)
        except PatientDetails.DoesNotExist:
            return Response({"error": "Patient details not found."}, status=status.HTTP_404_NOT_FOUND)

        engine = get_advice_engine()
        cards = [c.to_dict() for c in engine.generate(pd)]
        return Response(cards, status=status.HTTP_200_OK)
