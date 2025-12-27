from django.urls import path
from .views import AppointmentCreateView, DoctorSearchView, mark_no_show

urlpatterns = [
    path("", AppointmentCreateView.as_view(), name="appointment-create"),
    path("doctors/search/", DoctorSearchView.as_view(), name="doctor-search"),
    path("<int:pk>/mark-no-show/", mark_no_show, name="appointment-mark-no-show"),


]
