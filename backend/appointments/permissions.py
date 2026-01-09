from rest_framework.permissions import BasePermission

class IsDoctorOrAdmin(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if getattr(user, "role", "") == "doctor":
            return True
        if getattr(user, "is_staff", False) or getattr(user, "is_superuser", False):
            return True
        return False
