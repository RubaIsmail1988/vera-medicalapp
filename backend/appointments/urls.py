from django.urls import path
from .views import (
    AppointmentCreateView,
    DoctorSearchView,
    DoctorVisitTypesView,
    mark_no_show,
    cancel_appointment,
    confirm_appointment,
    DoctorAvailableSlotsView,
    MyAppointmentsView,
)

urlpatterns = [
    # Create appointment (Patient)
    path("", AppointmentCreateView.as_view(), name="appointment-create"),

    # Doctor search (Patient / Authenticated)
    path("doctors/search/", DoctorSearchView.as_view(), name="doctor-search"),

    # Doctor visit types for booking (central + specific)
    path(
        "doctors/<int:doctor_id>/visit-types/",
        DoctorVisitTypesView.as_view(),
        name="doctor-visit-types",
    ),

    # Doctor actions
    path("<int:pk>/mark-no-show/", mark_no_show, name="appointment-mark-no-show"),

    # Cancel appointment (patient / doctor / admin)
    path("<int:pk>/cancel/", cancel_appointment, name="appointment-cancel"),

    # Confirm appointment (doctor/admin)
    path("<int:pk>/confirm/", confirm_appointment, name="appointment-confirm"),

    #slots
    path("doctors/<int:doctor_id>/slots/", DoctorAvailableSlotsView.as_view(), name="doctor-slots"),

    #My appointments
    path("my/", MyAppointmentsView.as_view(), name="my-appointments"),

]
