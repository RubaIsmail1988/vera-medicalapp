from django.urls import path
from .views import (
    AppointmentCreateView,
    DoctorSearchView,
    DoctorVisitTypesView,
    mark_no_show,
    cancel_appointment,
    confirm_appointment,
    DoctorAvailableSlotsView,
    DoctorAvailableSlotsRangeView,
    MyAppointmentsView,
    DoctorAbsenceListCreateView,
    DoctorAbsenceDetailView,

    # NEW
    UrgentRequestCreateView,
    EmergencyAbsenceCreateView,
    MyUrgentRequestsView,
    UrgentRequestRejectView,
    UrgentRequestScheduleView,

)

urlpatterns = [
    # -----------------------------
    # Appointments
    # -----------------------------

    # Create appointment (Patient)
    path("", AppointmentCreateView.as_view(), name="appointment-create"),

    # My appointments (Patient / Doctor)
    path("my/", MyAppointmentsView.as_view(), name="my-appointments"),

    # Doctor actions on appointment
    path("<int:pk>/mark-no-show/", mark_no_show, name="appointment-mark-no-show"),
    path("<int:pk>/cancel/", cancel_appointment, name="appointment-cancel"),
    path("<int:pk>/confirm/", confirm_appointment, name="appointment-confirm"),

    # -----------------------------
    # Doctors & booking helpers
    # -----------------------------

    # Doctor search
    path("doctors/search/", DoctorSearchView.as_view(), name="doctor-search"),

    # Doctor visit types (central + specific)
    path(
        "doctors/<int:doctor_id>/visit-types/",
        DoctorVisitTypesView.as_view(),
        name="doctor-visit-types",
    ),

    # Available slots (single day)
    path(
        "doctors/<int:doctor_id>/slots/",
        DoctorAvailableSlotsView.as_view(),
        name="doctor-slots",
    ),

    # Available slots (range)
    path(
        "doctors/<int:doctor_id>/slots-range/",
        DoctorAvailableSlotsRangeView.as_view(),
        name="doctor-slots-range",
    ),

    # -----------------------------
    # Urgent scheduling (NEW)
    # -----------------------------

    # Create urgent request (when no slots + high triage)
    path(
        "urgent-requests/",
        UrgentRequestCreateView.as_view(),
        name="urgent-request-create",
    ),


    # Doctor views for urgent requests
    path(
        "urgent-requests/my/",
        MyUrgentRequestsView.as_view(),
        name="urgent-request-my",
    ),
    path(
        "urgent-requests/<int:pk>/reject/",
        UrgentRequestRejectView.as_view(),
        name="urgent-request-reject",
    ),
    path(
        "urgent-requests/<int:pk>/schedule/",
        UrgentRequestScheduleView.as_view(),
        name="urgent-request-schedule",
    ),

    # -----------------------------
    # Doctor absences
    # -----------------------------

    # Planned absences (Doctor/Admin)
    path(
        "absences/",
        DoctorAbsenceListCreateView.as_view(),
        name="doctor-absence-list-create",
    ),
    path(
        "absences/<int:pk>/",
        DoctorAbsenceDetailView.as_view(),
        name="doctor-absence-detail",
    ),

    # Emergency absence (Doctor only, cancels appointments + tokens)
    path(
        "absences/emergency/",
        EmergencyAbsenceCreateView.as_view(),
        name="doctor-emergency-absence-create",
    ),
]
