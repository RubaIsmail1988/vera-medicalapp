from rest_framework.permissions import BasePermission

class IsOwnerOrAdmin(BasePermission):
    """
    يسمح لصاحب الحساب نفسه أو للأدمن فقط بالتعامل مع التفاصيل.
    يفترض أن object (PatientDetails أو DoctorDetails) فيه .user
    """

    def has_object_permission(self, request, view, obj):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        # أدمن
        if getattr(user, 'role', None) == 'admin' or user.is_staff or user.is_superuser:
            return True

        # صاحب التفاصيل نفسه
        return obj.user == user


class IsDoctorOwnerOrAdmin(BasePermission):
    """
    يسمح للطبيب صاحب السجل أو الأدمن فقط.
    
    """

    def has_object_permission(self, request, view, obj):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        # Admin
        if getattr(user, "role", None) == "admin" or user.is_staff or user.is_superuser:
            return True

        # Owner Doctor
        return getattr(obj, "doctor_id", None) == user.id
