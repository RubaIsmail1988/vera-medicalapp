from django.urls import path

from .views import DeviceTokenUpsertView

urlpatterns = [
    path("devices/", DeviceTokenUpsertView.as_view(), name="device-token-upsert"),
]
