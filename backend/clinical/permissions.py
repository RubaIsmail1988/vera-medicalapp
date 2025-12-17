from rest_framework.permissions import BasePermission


def is_admin(user) -> bool:
    # Admin حقيقي عبر صلاحيات Django أو عبر role=admin
    return bool(
        getattr(user, "is_staff", False)
        or getattr(user, "is_superuser", False)
        or getattr(user, "role", "") == "admin"
    )


def is_doctor(user) -> bool:
    if is_admin(user):
        return True
    return getattr(user, "role", "") == "doctor"


def is_patient(user) -> bool:
    if is_admin(user):
        return True
    return getattr(user, "role", "") == "patient"


class IsDoctor(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and is_doctor(request.user))


class IsPatient(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and is_patient(request.user))
