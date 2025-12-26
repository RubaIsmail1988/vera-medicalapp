from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    # Registration
    PatientRegistrationView,
    DoctorRegistrationView,

    # Login
    CustomLoginView,

    # Details create
    PatientDetailsCreateView,
    DoctorDetailsCreateView,

    # Details CRUD
    DoctorDetailsRetrieveUpdateDestroyView,
    PatientDetailsRetrieveUpdateDestroyView,

    # Listing
    DoctorsListView,
    PatientsListView,
    UsersListView,

    # Activate / Deactivate
    activate_user,
    deactivate_user,

    #طلب حذف حساب
    AccountDeletionRequestCreateView,
    MyAccountDeletionRequestsView,
    AccountDeletionRequestListView,
    approve_account_deletion_request,
    reject_account_deletion_request,

    # Hospitals
    HospitalListCreateView,
    HospitalRetrieveUpdateDestroyView,

    # Labs
    LabListCreateView,
    LabRetrieveUpdateDestroyView,

    # CurrentUser:
    CurrentUserView,

    GovernorateListView,
)
from .views import (
    PasswordResetRequestView,
    PasswordResetVerifyView,
    PasswordResetConfirmView,
    AppointmentTypeListCreateView,
    AppointmentTypeRetrieveUpdateDestroyView,
    DoctorAppointmentTypeListCreateView,
    DoctorAppointmentTypeRetrieveUpdateDestroyView,
    DoctorAvailabilityListCreateView,
    DoctorAvailabilityRetrieveUpdateDestroyView,
    AppointmentTypeReadOnlyListView,
    DoctorSpecificVisitTypeListCreateView,
    DoctorSpecificVisitTypeRetrieveUpdateDestroyView,
)


urlpatterns = [

    # -------------------------------------------------------------------------
    # Authentication & Registration
    # -------------------------------------------------------------------------
    path("register/patient/", PatientRegistrationView.as_view(), name="register-patient"),
    path("register/doctor/", DoctorRegistrationView.as_view(), name="register-doctor"),

    path("login/", CustomLoginView.as_view(), name="login"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),

    # -------------------------------------------------------------------------
    # Create details after registration
    # -------------------------------------------------------------------------
    path("patient-details/", PatientDetailsCreateView.as_view(), name="patient-details-create"),
    path("doctor-details/", DoctorDetailsCreateView.as_view(), name="doctor-details-create"),

    # -------------------------------------------------------------------------
    # CRUD on details using user_id
    # -------------------------------------------------------------------------
    path("doctor-details/<int:user_id>/", DoctorDetailsRetrieveUpdateDestroyView.as_view(), name="doctor-detail"),
    path("patient-details/<int:user_id>/", PatientDetailsRetrieveUpdateDestroyView.as_view(), name="patient-detail"),

    # -------------------------------------------------------------------------
    # Listing users
    # -------------------------------------------------------------------------
    path("doctors/", DoctorsListView.as_view(), name="doctors-list"),
    path("patients/", PatientsListView.as_view(), name="patients-list"),
    path("users/", UsersListView.as_view(), name="users-list"),

    # -------------------------------------------------------------------------
    # Account deletion requests
    # -------------------------------------------------------------------------
    path(
        "account-deletion/request/",
        AccountDeletionRequestCreateView.as_view(),
        name="account-deletion-request",),

    path(
        "account-deletion/my-requests/",
        MyAccountDeletionRequestsView.as_view(),
        name="my-account-deletion-requests",),

    path(
        "account-deletion/requests/",
        AccountDeletionRequestListView.as_view(),
        name="account-deletion-requests-list",),

    path(
        "account-deletion/requests/<int:pk>/approve/",
        approve_account_deletion_request,
        name="approve-account-deletion-request",),

    path(
        "account-deletion/requests/<int:pk>/reject/",
        reject_account_deletion_request,
        name="reject-account-deletion-request",),


    # -------------------------------------------------------------------------
    # Hospitals
    # -------------------------------------------------------------------------
    path("hospitals/", HospitalListCreateView.as_view(), name="hospital-list-create"),
    path("hospitals/<int:id>/", HospitalRetrieveUpdateDestroyView.as_view(), name="hospital-detail"),

    # -------------------------------------------------------------------------
    # Labs
    # -------------------------------------------------------------------------
    path("labs/", LabListCreateView.as_view(), name="lab-list-create"),
    path("labs/<int:id>/", LabRetrieveUpdateDestroyView.as_view(), name="lab-detail"),

    # -------------------------------------------------------------------------
    # Activation / Deactivation
    # -------------------------------------------------------------------------
    path("users/<int:pk>/activate/", activate_user, name="activate-user"),
    path("users/<int:pk>/deactivate/", deactivate_user, name="deactivate-user"),

    # -------------------------------------------------------------------------
    # Current user (Profile / Me)
    # -------------------------------------------------------------------------
    path("me/", CurrentUserView.as_view(), name="current-user"),

    # -------------------------------------------------------------------------
    # Password Reset (OTP)
    # -------------------------------------------------------------------------
    path("password-reset/request/", PasswordResetRequestView.as_view(), name="password-reset-request"),
    path("password-reset/verify/", PasswordResetVerifyView.as_view(), name="password-reset-verify"),
    path("password-reset/confirm/", PasswordResetConfirmView.as_view(), name="password-reset-confirm"),

    # -------------------------------------------------------------------------
    # Phase C - Scheduling Configuration
    # -------------------------------------------------------------------------
    path("appointment-types/", AppointmentTypeListCreateView.as_view(), name="appointment-types-list-create"),
    path("appointment-types/<int:pk>/", AppointmentTypeRetrieveUpdateDestroyView.as_view(), name="appointment-types-detail"),

    path("doctor-appointment-types/", DoctorAppointmentTypeListCreateView.as_view(), name="doctor-appointment-types-list-create"),
    path("doctor-appointment-types/<int:pk>/", DoctorAppointmentTypeRetrieveUpdateDestroyView.as_view(), name="doctor-appointment-types-detail"),

    path("doctor-availabilities/", DoctorAvailabilityListCreateView.as_view(), name="doctor-availabilities-list-create"),
    path("doctor-availabilities/<int:pk>/", DoctorAvailabilityRetrieveUpdateDestroyView.as_view(), name="doctor-availabilities-detail"),
    path("appointment-types-read/", AppointmentTypeReadOnlyListView.as_view(), name="appointment-types-read",),
    path(
        "doctor-specific-visit-types/",
        DoctorSpecificVisitTypeListCreateView.as_view(),
        name="doctor-specific-visit-types-list-create",
    ),
    path(
        "doctor-specific-visit-types/<int:pk>/",
        DoctorSpecificVisitTypeRetrieveUpdateDestroyView.as_view(),
        name="doctor-specific-visit-types-detail",
    ),
    # ...
    path("governorates/", GovernorateListView.as_view(), name="governorate-list"),
]
