// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/models/governorate.dart';
import '/models/register_request.dart';
import '/services/auth_service.dart';
import '/services/governorate_service.dart';
import '/utils/ui_helpers.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final AuthService authService = AuthService();
  final GovernorateService governorateService = GovernorateService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String role = 'patient';

  bool loading = false;

  // Password visibility
  bool obscurePassword = true;

  // Governorates (dropdown)
  bool loadingGovernorates = true;
  List<Governorate> governorates = const [];
  int? selectedGovernorateId;

  @override
  void initState() {
    super.initState();
    loadGovernorates();
  }

  Future<void> loadGovernorates() async {
    if (!mounted) return;
    setState(() => loadingGovernorates = true);

    try {
      final list = await governorateService.fetchGovernorates();
      if (!mounted) return;

      list.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        governorates = list;
        loadingGovernorates = false;

        // اجعل الاختيار صالحاً دائماً بالنسبة للقائمة الجديدة
        final bool exists =
            selectedGovernorateId != null &&
            governorates.any((g) => g.id == selectedGovernorateId);

        if (!exists) {
          selectedGovernorateId =
              governorates.isEmpty ? null : governorates.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingGovernorates = false;
        governorates = const [];
        selectedGovernorateId = null;
      });

      // هذا Fetch -> سلوك موحّد: SnackBar فقط إذا أردتِ، لكن هنا نتركه لأنه داخل شاشة Form (Action context)
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback:
            'تعذّر تحميل المحافظات. تأكد من الاتصال بالخادم ثم أعد المحاولة.',
      );
    }
  }

  String? emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  String? usernameValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'اسم المستخدم مطلوب';
    if (value.trim().length < 3) {
      return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
    }
    return null;
  }

  String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'كلمة المرور مطلوبة';
    if (value.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    return null;
  }

  String? phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'رقم الجوال مطلوب';
    final trimmed = value.trim();
    final phoneRegex = RegExp(r'^[0-9+\-\s]+$');
    if (!phoneRegex.hasMatch(trimmed)) return 'صيغة رقم الجوال غير صحيحة';
    return null;
  }

  String? addressValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'العنوان مطلوب';
    if (value.trim().length < 5) return 'الرجاء إدخال عنوان أوضح';
    return null;
  }

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;

    final governorateId = selectedGovernorateId;
    if (governorateId == null) {
      showAppSnackBar(
        context,
        'يرجى اختيار المحافظة.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => loading = true);

    final request = RegisterRequest(
      email: emailController.text.trim().toLowerCase(),
      username: usernameController.text.trim(),
      password: passwordController.text.trim(),
      phone: phoneController.text.trim(),
      governorate: governorateId,
      address: addressController.text.trim(),
      role: role,
    );

    try {
      final response = await authService.register(request);
      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() => loading = false);

        final email = emailController.text.trim().toLowerCase();

        if (role == 'patient') {
          showAppSuccessSnackBar(
            context,
            'تم إنشاء حساب المريض بنجاح. يمكنك الآن تسجيل الدخول.',
          );
          context.go('/login', extra: {'prefillEmail': email});
          return;
        }

        if (role == 'doctor') {
          showAppSnackBar(
            context,
            'تم إرسال طلب التسجيل. حساب الطبيب بانتظار التفعيل.',
            type: AppSnackBarType.info,
          );
          context.go('/waiting-activation');
          return;
        }

        showAppSuccessSnackBar(context, 'تم إنشاء الحساب بنجاح.');
        context.go('/login');
        return;
      }

      // HTTP non-201 -> Action error موحّد عبر statusCode + data
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        statusCode: response.statusCode,
        data: response.body,
        fallback:
            'فشل إنشاء الحساب. يرجى التأكد من البيانات والمحاولة مرة أخرى.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'حدث خطأ غير متوقع أثناء التسجيل. حاول مرة أخرى.',
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !loading && !loadingGovernorates;

    final bool hasSelected =
        selectedGovernorateId != null &&
        governorates.any((g) => g.id == selectedGovernorateId);

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: emailValidator,
                            enabled: !loading,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                            ),
                            validator: usernameValidator,
                            enabled: !loading,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: passwordController,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              suffixIcon: IconButton(
                                tooltip: obscurePassword ? 'إظهار' : 'إخفاء',
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed:
                                    loading
                                        ? null
                                        : () {
                                          setState(() {
                                            obscurePassword = !obscurePassword;
                                          });
                                        },
                              ),
                            ),
                            obscureText: obscurePassword,
                            validator: passwordValidator,
                            enabled: !loading,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'رقم الجوال',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: phoneValidator,
                            enabled: !loading,
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<int>(
                            value: hasSelected ? selectedGovernorateId : null,
                            decoration: InputDecoration(
                              labelText: 'المحافظة',
                              suffixIcon:
                                  loadingGovernorates
                                      ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                      : IconButton(
                                        tooltip: 'تحديث القائمة',
                                        onPressed:
                                            (loading || loadingGovernorates)
                                                ? null
                                                : loadGovernorates,
                                        icon: const Icon(Icons.refresh),
                                      ),
                            ),
                            items:
                                governorates
                                    .map(
                                      (g) => DropdownMenuItem<int>(
                                        value: g.id,
                                        child: Text(g.name),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (!canSubmit || governorates.isEmpty)
                                    ? null
                                    : (value) {
                                      setState(() {
                                        selectedGovernorateId = value;
                                      });
                                    },
                            validator:
                                (value) =>
                                    value == null
                                        ? 'يرجى اختيار المحافظة'
                                        : null,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: addressController,
                            decoration: const InputDecoration(
                              labelText: 'العنوان',
                            ),
                            validator: addressValidator,
                            enabled: !loading,
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: role,
                            decoration: const InputDecoration(
                              labelText: 'الدور',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'patient',
                                child: Text('مريض'),
                              ),
                              DropdownMenuItem(
                                value: 'doctor',
                                child: Text('طبيب'),
                              ),
                            ],
                            onChanged:
                                loading
                                    ? null
                                    : (value) {
                                      if (value == null) return;
                                      setState(() => role = value);
                                    },
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: canSubmit ? register : null,
                              child:
                                  loading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('تسجيل'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading ? null : () => context.go('/login'),
                    child: const Text('لديك حساب مسبقاً؟ تسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
