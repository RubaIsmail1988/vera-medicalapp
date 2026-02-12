// ----------------- mobile/lib/screens/auth/login_screen.dart -----------------
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_logo.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;
  bool obscurePassword = true;

  bool didApplyPrefill = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // تطبيق prefillEmail مرة واحدة فقط عند الرجوع من /register
    if (didApplyPrefill) return;

    final Object? extra = GoRouterState.of(context).extra;
    if (extra is Map) {
      final dynamic v = extra['prefillEmail'];
      final String email = (v ?? '').toString().trim();
      if (email.isNotEmpty) {
        emailController.text = email;
      }
    }

    didApplyPrefill = true;
  }

  String? emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'البريد الإلكتروني مطلوب';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(text)) return 'صيغة البريد الإلكتروني غير صحيحة';
    return null;
  }

  String? passwordValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'كلمة المرور مطلوبة';
    if (text.length < 4) return 'كلمة المرور قصيرة جداً';
    return null;
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final result = await authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;

      if (result == null) {
        setState(() => loading = false);
        showAppErrorSnackBar(
          context,
          'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        );
        return;
      }

      final data = result;

      if (data['error'] == 'not_active') {
        setState(() => loading = false);
        context.go('/waiting-activation');
        return;
      }

      final String role = (data['role'] ?? '').toString();
      final bool isActive = data['is_active'] == true;

      final dynamic rawUserId = data['user_id'];
      final int userId =
          rawUserId is int
              ? rawUserId
              : int.tryParse(rawUserId?.toString() ?? '') ?? 0;

      final String accessToken = (data['access_token'] ?? '').toString();

      if (!isActive) {
        setState(() => loading = false);
        context.go('/waiting-activation');
        return;
      }

      if (accessToken.isEmpty || userId == 0 || role.isEmpty) {
        setState(() => loading = false);
        showAppSnackBar(
          context,
          'الاستجابة من الخادم غير مكتملة، حاول مرة أخرى',
          type: AppSnackBarType.warning,
        );
        return;
      }

      // يحدّث prefs (currentUserName/currentUserEmail/currentUserRole/user_is_active...)
      await authService.fetchAndStoreCurrentUser();
      if (!mounted) return;

      setState(() => loading = false);
      MyApp.of(context).maybeStartPolling();

      // Admin -> Admin shell
      if (role == 'admin') {
        context.go('/admin');
        return;
      }

      // Doctor/Patient -> User shell
      context.go('/app');
      return;
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر تسجيل الدخول. حاول مرة أخرى.',
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الدخول إلى الحساب')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(width: 260, framed: false),
                  const SizedBox(height: 18),
                  Text(
                    ' ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  //   Text(
                  //    'يرجى تسجيل الدخول للمتابعة',
                  //   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  //     color: cs.onSurface.withValues(alpha: 0.72),
                  //   ),
                  // ),
                  const SizedBox(height: 16),
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
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            autocorrect: false,
                            enableSuggestions: false,
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
                                onPressed: () {
                                  setState(
                                    () => obscurePassword = !obscurePassword,
                                  );
                                },
                              ),
                            ),
                            obscureText: obscurePassword,
                            validator: passwordValidator,
                            enabled: !loading,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            autocorrect: false,
                            enableSuggestions: false,
                            onFieldSubmitted: (value) {
                              if (!loading) login();
                            },
                          ),

                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : login,
                              child:
                                  loading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('تسجيل الدخول'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed:
                                    loading
                                        ? null
                                        : () => context.go('/forgot-password'),
                                child: const Text('نسيت كلمة المرور؟'),
                              ),
                              TextButton(
                                onPressed:
                                    loading
                                        ? null
                                        : () => context.go('/register'),
                                child: const Text('إنشاء حساب'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
