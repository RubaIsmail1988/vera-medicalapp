from django.urls import path
from .views import AppointmentCreateView, DoctorSearchView

urlpatterns = [
    path("", AppointmentCreateView.as_view(), name="appointment-create"),
    path("doctors/search/", DoctorSearchView.as_view(), name="doctor-search"),


]
