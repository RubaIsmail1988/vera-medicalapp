
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import (
    UserRegistrationSerializer,
    PatientDetailsSerializer,
    DoctorDetailsSerializer,
    CustomTokenObtainPairSerializer,
    HospitalSerializer,
    LabSerializer,
    UserSerializer,
    AccountDeletionRequestCreateSerializer,
    AccountDeletionRequestListSerializer,
    CurrentUserSerializer,
    AppointmentTypeSerializer,
    DoctorAppointmentTypeSerializer,
    DoctorSpecificVisitTypeSerializer,
    DoctorAvailabilitySerializer,
    GovernorateSerializer,
)
from .models import CustomUser, PatientDetails, DoctorDetails, Hospital, Lab, AccountDeletionRequest,AppointmentType, DoctorAppointmentType, DoctorAvailability, Governorate, DoctorSpecificVisitType 
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAdminUser
from rest_framework.generics import ListAPIView
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.utils import timezone
from .permissions import IsOwnerOrAdmin, IsDoctorOwnerOrAdmin
from rest_framework.exceptions import PermissionDenied, ValidationError
from django.db import IntegrityError, transaction

User = get_user_model()

# تسجيل المستخدمين
class UserRegistrationView(generics.CreateAPIView):
    queryset = CustomUser.objects.all()
    serializer_class = UserRegistrationSerializer
    permission_classes = [AllowAny]


class PatientRegistrationView(UserRegistrationView):
    def perform_create(self, serializer):
        serializer.save(role="patient")


class DoctorRegistrationView(UserRegistrationView):
    def perform_create(self, serializer):
        serializer.save(role="doctor")

class UsersListView(ListAPIView):
    serializer_class = UserSerializer
    queryset = User.objects.all()

# CRUD للمريض
class PatientDetailsCreateView(generics.CreateAPIView):
    queryset = PatientDetails.objects.all()
    serializer_class = PatientDetailsSerializer

class PatientDetailsRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = PatientDetails.objects.all()
    serializer_class = PatientDetailsSerializer
    lookup_field = 'user_id'

    def get_permissions(self):
        # GET / PUT / PATCH -> مسموح للمستخدم العادي (المريض نفسه) مثلاً
        if self.request.method in ['GET', 'PUT', 'PATCH']:
            return [IsAuthenticated()]
        # DELETE -> للأدمن فقط
        elif self.request.method == 'DELETE':
            return [IsAdminUser()]
        return [IsAuthenticated(), IsOwnerOrAdmin()]

    def destroy(self, request, *args, **kwargs):

        user_id = kwargs.get("user_id")

        # 1) الحصول على المستخدم أولاً
        try:
            user = CustomUser.objects.get(id=user_id, role='patient')
        except CustomUser.DoesNotExist:
            return Response({"error": "Patient user not found."}, status=404)

        # 2) محاولة جلب التفاصيل (قد لا تكون موجودة)
        try:
            patient_detail = PatientDetails.objects.get(user_id=user_id)
            patient_detail.is_archived = True
            patient_detail.save()
        except PatientDetails.DoesNotExist:
            patient_detail = None

        # 3) تعطيل حساب المستخدم دائماً
        user.is_active = False
        user.save()

        return Response(
            {"success": "Patient account deactivated."},
            status=status.HTTP_200_OK
        )
class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = CurrentUserSerializer(request.user)
        return Response(serializer.data)


class PatientsListView(ListAPIView):
    serializer_class = UserSerializer

    def get_queryset(self):
        return User.objects.filter(role='patient')

# CRUD للطبيب
class DoctorDetailsCreateView(generics.CreateAPIView):
    queryset = DoctorDetails.objects.all()
    serializer_class = DoctorDetailsSerializer

class DoctorDetailsRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = DoctorDetails.objects.all()
    serializer_class = DoctorDetailsSerializer
    lookup_field = 'user_id'

    def get_permissions(self):
        if self.request.method in ['GET', 'PUT', 'PATCH']:
            return [IsAuthenticated()]
        elif self.request.method == 'DELETE':
            return [IsAdminUser()]
        return [IsAuthenticated(), IsOwnerOrAdmin()]

    def destroy(self, request, *args, **kwargs):

        user_id = kwargs.get("user_id")

        # 1) الحصول على المستخدم أولاً
        try:
            user = CustomUser.objects.get(id=user_id, role='doctor')
        except CustomUser.DoesNotExist:
            return Response({"error": "Doctor user not found."}, status=404)

        # 2) محاولة جلب التفاصيل (قد لا تكون موجودة)
        try:
            doctor_detail = DoctorDetails.objects.get(user_id=user_id)
            doctor_detail.is_archived = True
            doctor_detail.save()
        except DoctorDetails.DoesNotExist:
            doctor_detail = None

        # 3) تعطيل حساب المستخدم دائماً
        user.is_active = False
        user.save()

        return Response(
            {"success": "Doctor account deactivated."},
            status=status.HTTP_200_OK
        )

class DoctorsListView(ListAPIView):
    serializer_class = UserSerializer

    def get_queryset(self):
        return User.objects.filter(role='doctor')

# تسجيل الدخول
class CustomLoginView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

#إنشاء طلب حذف حساب
class AccountDeletionRequestCreateView(generics.CreateAPIView):
    """
    endpoint: POST /api/accounts/account-deletion/request/
    يستخدمه المريض أو الطبيب لطلب حذف الحساب.
    """
    serializer_class = AccountDeletionRequestCreateSerializer
    permission_classes = [IsAuthenticated]

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

#عرض أحدث طلبات الحذف الخاصة بالمستخدم
class MyAccountDeletionRequestsView(generics.ListAPIView):
    """
    endpoint: GET /api/accounts/account-deletion/my-requests/
    يعرض آخر طلبات الحذف للمستخدم الحالي (مثلاً آخر 5).
    """
    serializer_class = AccountDeletionRequestListSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return AccountDeletionRequest.objects.filter(
            user=self.request.user
        ).order_by('-created_at')[:5]

#عرض طلبات الحذف للأدمن
class AccountDeletionRequestListView(generics.ListAPIView):
    """
    endpoint: GET /api/accounts/account-deletion/requests/
    للأدمن فقط: يعرض جميع طلبات حذف الحساب.
    """
    serializer_class = AccountDeletionRequestListSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        return AccountDeletionRequest.objects.all().order_by('-created_at')

#للأدمن الموافقة على طلب الحذف
@api_view(['POST'])
@permission_classes([IsAdminUser])
def approve_account_deletion_request(request, pk):
    """
    endpoint: POST /api/accounts/account-deletion/requests/<pk>/approve/
    عند الموافقة:
      - status = 'approved'
      - user.is_active = False
      - DoctorDetails/PatientDetails.is_archived = True إن وجدت
    """
    try:
        deletion_request = AccountDeletionRequest.objects.get(pk=pk)
    except AccountDeletionRequest.DoesNotExist:
        return Response({'error': 'Deletion request not found'}, status=404)

    if deletion_request.status != 'pending':
        return Response({'error': 'Request already processed'}, status=400)

    user = deletion_request.user

    # تعطيل الحساب
    user.is_active = False
    user.save()

    # أرشفة التفاصيل إن وجدت
    if user.role == 'doctor':
        try:
            details = DoctorDetails.objects.get(user=user)
            details.is_archived = True
            details.save()
        except DoctorDetails.DoesNotExist:
            pass
    elif user.role == 'patient':
        try:
            details = PatientDetails.objects.get(user=user)
            details.is_archived = True
            details.save()
        except PatientDetails.DoesNotExist:
            pass

    # تحديث الطلب نفسه
    deletion_request.status = 'approved'
    deletion_request.processed_by = request.user
    deletion_request.processed_at = timezone.now()
    deletion_request.admin_note = request.data.get('admin_note', '')
    deletion_request.save()

    return Response({'success': True, 'message': 'Account deletion approved.'})

#للأدمن رفض طلب الحذف
@api_view(['POST'])
@permission_classes([IsAdminUser])
def reject_account_deletion_request(request, pk):
    """
    endpoint: POST /api/accounts/account-deletion/requests/<pk>/reject/
    يرفض طلب الحذف ولا يغيّر حالة الحساب.
    """
    try:
        deletion_request = AccountDeletionRequest.objects.get(pk=pk)
    except AccountDeletionRequest.DoesNotExist:
        return Response({'error': 'Deletion request not found'}, status=404)

    if deletion_request.status != 'pending':
        return Response({'error': 'Request already processed'}, status=400)

    deletion_request.status = 'rejected'
    deletion_request.processed_by = request.user
    deletion_request.processed_at = timezone.now()
    deletion_request.admin_note = request.data.get('admin_note', '')
    deletion_request.save()

    return Response({'success': True, 'message': 'Account deletion rejected.'})



# HOSPITAL CRUD
class HospitalListCreateView(generics.ListCreateAPIView):
    queryset = Hospital.objects.all()
    serializer_class = HospitalSerializer

class HospitalRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Hospital.objects.all()
    serializer_class = HospitalSerializer
    lookup_field = 'id'

# LAB CRUD
class LabListCreateView(generics.ListCreateAPIView):
    queryset = Lab.objects.all()
    serializer_class = LabSerializer

class LabRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Lab.objects.all()
    serializer_class = LabSerializer
    lookup_field = 'id'

@api_view(['POST'])
@permission_classes([IsAdminUser])
def activate_user(request, pk):
    try:
        user = CustomUser.objects.get(pk=pk)
        user.is_active = True
        user.save()

        # إعادة التفاصيل إذا كانت موجودة
        if user.role == 'doctor':
            details = DoctorDetails.objects.filter(user=user).first()
        elif user.role == 'patient':
            details = PatientDetails.objects.filter(user=user).first()
        else:
            details = None

        if details:
            details.is_archived = False
            details.save()

        return Response({"success": True})

    except CustomUser.DoesNotExist:
        return Response({"error": "User not found"}, status=404)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def deactivate_user(request, pk):
    """
    Endpoint لتعطيل مستخدم (طبيب أو مريض) من قبل الأدمن.
    عند التعطيل:
      - user.is_active = False
      - أرشفة تفاصيل الطبيب/المريض إن وجدت
      - تحويل جميع طلبات الحذف pending الخاصة بهذا المستخدم إلى approved
        مع تعيين processed_at و processed_by و admin_note افتراضية.
    """
    try:
        user = CustomUser.objects.get(pk=pk)
    except CustomUser.DoesNotExist:
        return Response({'error': 'User not found'}, status=404)

    # تعطيل الحساب
    user.is_active = False
    user.save()

    # أرشفة التفاصيل
    if user.role == 'doctor':
        try:
            details = DoctorDetails.objects.get(user=user)
            details.is_archived = True
            details.save()
        except DoctorDetails.DoesNotExist:
            pass
    elif user.role == 'patient':
        try:
            details = PatientDetails.objects.get(user=user)
            details.is_archived = True
            details.save()
        except PatientDetails.DoesNotExist:
            pass

    #  تحديث جميع طلبات الحذف المعلّقة لهذا المستخدم
    try:
        pending_requests = AccountDeletionRequest.objects.filter(
            user=user,
            status='pending',
        )

        for req in pending_requests:
            req.status = 'approved'
            req.processed_at = timezone.now()
            req.processed_by = request.user  # الأدمن الحالي
            # إذا لم توجد ملاحظة، نضع ملاحظة افتراضية
            if not req.admin_note:
                req.admin_note = 'تمت الموافقة على حذف الحساب بواسطة تعطيل المستخدم.'
            req.save()
    except Exception:
        # لا نريد كسر العملية لو حدث خطأ هنا
        pass

    return Response(
        {
            'success': True,
            'message': f'User {user.username} has been deactivated.',
        }
    )
from django.core.mail import send_mail
from django.conf import settings
from .models import PasswordResetOTP
from .serializers import (
    PasswordResetRequestSerializer,
    PasswordResetVerifySerializer,
    PasswordResetConfirmSerializer,
)
class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"].strip().lower()

        # لأسباب أمنية: لا نفصح إن كان البريد موجود أو لا
        user = CustomUser.objects.filter(email=email).first()
        if user:
            otp = PasswordResetOTP.create_for_user(user, minutes=10)

            subject = "Reset Password OTP - Vera Smart Health"
            message = (
                "You requested to reset your password.\n\n"
                f"Your OTP code is: {otp.code}\n"
                "This code expires in 10 minutes.\n\n"
                "If you did not request this, please ignore this email."
            )

            send_mail(
                subject=subject,
                message=message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=False,
            )

        return Response({"success": True}, status=status.HTTP_200_OK)


class PasswordResetVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"].strip().lower()
        code = serializer.validated_data["code"].strip()

        user = CustomUser.objects.filter(email=email).first()
        if not user:
            # نفس الرد دائمًا
            return Response({"valid": False}, status=status.HTTP_200_OK)

        otp = PasswordResetOTP.objects.filter(
            user=user,
            code=code,
            is_used=False,
        ).order_by("-created_at").first()

        if not otp or otp.is_expired():
            return Response({"valid": False}, status=status.HTTP_200_OK)

        return Response({"valid": True}, status=status.HTTP_200_OK)


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"].strip().lower()
        code = serializer.validated_data["code"].strip()
        new_password = serializer.validated_data["new_password"]

        user = CustomUser.objects.filter(email=email).first()
        if not user:
            return Response({"success": False}, status=status.HTTP_200_OK)

        otp = PasswordResetOTP.objects.filter(
            user=user,
            code=code,
            is_used=False,
        ).order_by("-created_at").first()

        if not otp or otp.is_expired():
            return Response({"success": False}, status=status.HTTP_200_OK)

        # تحديث كلمة المرور
        user.set_password(new_password)
        user.save()

        # إغلاق الـ OTP
        otp.is_used = True
        otp.save()

        return Response({"success": True}, status=status.HTTP_200_OK)

# -----------------------------
# Phase C - Appointment Types (Admin only)
# -----------------------------
class AppointmentTypeListCreateView(generics.ListCreateAPIView):
    queryset = AppointmentType.objects.all()
    serializer_class = AppointmentTypeSerializer
    permission_classes = [IsAdminUser]
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context


class AppointmentTypeRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = AppointmentType.objects.all()
    serializer_class = AppointmentTypeSerializer
    permission_classes = [IsAdminUser]


# -----------------------------
# Phase C - DoctorAppointmentType
# Doctor manages own, admin can see all
# -----------------------------
class DoctorAppointmentTypeListCreateView(generics.ListCreateAPIView):
    serializer_class = DoctorAppointmentTypeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", None) == "admin" or user.is_staff or user.is_superuser:
            return DoctorAppointmentType.objects.all()
        if getattr(user, "role", None) == "doctor":
            return DoctorAppointmentType.objects.filter(doctor=user)
        return DoctorAppointmentType.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        if getattr(user, "role", None) != "doctor":
            raise PermissionDenied("Only doctors can create DoctorAppointmentType.")

        try:
            with transaction.atomic():
                serializer.save(doctor=user)
        except IntegrityError:
            # هذا يحصل عند محاولة إدخال نفس (doctor, appointment_type) مرة ثانية
            raise ValidationError({
                "appointment_type": "This appointment type is already configured for this doctor."
            })

class DoctorAppointmentTypeRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DoctorAppointmentTypeSerializer
    permission_classes = [IsAuthenticated, IsDoctorOwnerOrAdmin]

    def get_queryset(self):
        # مهم: نقيّد queryset حتى لا يستطيع المستخدم الوصول لسجلات غيره
        user = self.request.user
        if getattr(user, "role", None) == "admin" or user.is_staff or user.is_superuser:
            return DoctorAppointmentType.objects.all()
        if getattr(user, "role", None) == "doctor":
            return DoctorAppointmentType.objects.filter(doctor=user)
        return DoctorAppointmentType.objects.none()



class DoctorSpecificVisitTypeListCreateView(generics.ListCreateAPIView):
    serializer_class = DoctorSpecificVisitTypeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", None) == "admin" or user.is_staff or user.is_superuser:
            return DoctorSpecificVisitType.objects.all()
        if getattr(user, "role", None) == "doctor":
            return DoctorSpecificVisitType.objects.filter(doctor=user)
        return DoctorSpecificVisitType.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        if getattr(user, "role", None) != "doctor":
            raise PermissionDenied("Only doctors can create DoctorSpecificVisitType.")

        try:
            with transaction.atomic():
                serializer.save(doctor=user)
        except IntegrityError:
            raise ValidationError({"name": "This visit type name already exists for this doctor."})
#-----------------------------

#-----------------------------

class DoctorSpecificVisitTypeRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DoctorSpecificVisitTypeSerializer
    permission_classes = [IsAuthenticated, IsDoctorOwnerOrAdmin]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", None) == "admin" or user.is_staff or user.is_superuser:
            return DoctorSpecificVisitType.objects.all()
        if getattr(user, "role", None) == "doctor":
            return DoctorSpecificVisitType.objects.filter(doctor=user)
        return DoctorSpecificVisitType.objects.none()

# -----------------------------
# Phase C - DoctorAvailability
# Doctor manages own, admin can see all
# -----------------------------
class DoctorAvailabilityListCreateView(generics.ListCreateAPIView):
    serializer_class = DoctorAvailabilitySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", None) == "admin" or user.is_staff or user.is_superuser:
            return DoctorAvailability.objects.all()
        if getattr(user, "role", None) == "doctor":
            return DoctorAvailability.objects.filter(doctor=user)
        return DoctorAvailability.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        if getattr(user, "role", None) != "doctor":
            raise PermissionDenied("Only doctors can create DoctorAvailability.")
        serializer.save(doctor=user)


class DoctorAvailabilityRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DoctorAvailabilitySerializer
    permission_classes = [IsAuthenticated, IsDoctorOwnerOrAdmin]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", None) == "admin" or user.is_staff or user.is_superuser:
            return DoctorAvailability.objects.all()
        if getattr(user, "role", None) == "doctor":
            return DoctorAvailability.objects.filter(doctor=user)
        return DoctorAvailability.objects.none()


class AppointmentTypeReadOnlyListView(ListAPIView):
    queryset = AppointmentType.objects.all()
    serializer_class = AppointmentTypeSerializer
    permission_classes = [IsAuthenticated]


class GovernorateListView(generics.ListAPIView):
    permission_classes = [AllowAny]
    serializer_class = GovernorateSerializer

    def get_queryset(self):
        return Governorate.objects.all().order_by("name")