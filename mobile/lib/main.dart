// ----------------- mobile/lib/main.dart -----------------
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';

// Auth
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/waiting_activation_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_verify_otp_screen.dart';
import 'screens/auth/reset_password_new_password_screen.dart';

// Shells
import 'screens/user/user_shell_screen.dart';
import 'screens/admin/admin_shell_screen.dart';

// System
import 'screens/system/splash_screen.dart';

// User details
import 'screens/user/patient_details_screen.dart';
import 'screens/user/doctor_details_screen.dart';
import 'screens/user/hospital_public_detail_screen.dart';
import 'screens/user/lab_public_detail_screen.dart';
import 'screens/user/account_deletion_status_screen.dart';
import 'screens/user/clinical/order_details_screen.dart';

// DoctorScheduling
import 'screens/doctor/doctor_scheduling_settings_screen.dart';
import 'screens/doctor/doctor_availability_screen.dart';
import 'screens/doctor/doctor_visit_types_screen.dart';
import 'screens/doctor/doctor_absences_screen.dart';
// DoctorUrgentSearchScrean
import 'screens/doctor/doctor_urgent_requests_screen.dart';

// Appointment
import 'screens/user/appointments/book_appointment_screen.dart';
import 'screens/user/appointments/doctor_search_screen.dart';

// Notification
import '/services/local_notifications_service.dart';
import 'screens/user/inbox/inbox_screen.dart';

// Services
import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/services/polling_notifications_service.dart';

// navigation_keys
import 'utils/navigation_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local notifications (safe to init once here)
  await LocalNotificationsService.init();

  runApp(const MyApp());
}

/* -------------------------------------------------------------------------- */
/*                                   MyApp                                    */
/* -------------------------------------------------------------------------- */

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ThemeMode themeMode = ThemeMode.dark;

  late final AuthService _authService;
  late final ClinicalService _clinicalService;
  late final PollingNotificationsService _polling;

  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authService = AuthService();
    _clinicalService = ClinicalService(authService: _authService);

    _polling = PollingNotificationsService(
      authService: _authService,
      clinicalService: _clinicalService,
      intervalSeconds: 10,
      pageSize: 50,
    );

    // ignore: unawaited_futures
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ignore: unawaited_futures
    _polling.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // سياسة بسيطة:
    // - بالخلفية: أوقف polling
    // - عند العودة: ابدأ إذا كان المستخدم مسجّل دخول
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // ignore: unawaited_futures
      _polling.stop();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // ignore: unawaited_futures
      maybeStartPolling();
    }
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // إذا كان المستخدم مسجّل دخول من قبل، ابدأ polling مباشرة.
    await maybeStartPolling();
  }

  // --------------------------------------------------------------------------
  // Polling control (تستدعيها من Login/Logout)
  // --------------------------------------------------------------------------

  Future<void> maybeStartPolling() async {
    final prefs = await SharedPreferences.getInstance();
    final access = (prefs.getString("access_token") ?? "").trim();
    final userId = prefs.getInt("user_id") ?? 0;

    if (access.isEmpty || userId <= 0) {
      await _polling.stop();
      return;
    }

    await _polling.start();
  }

  Future<void> stopPolling() => _polling.stop();

  // --------------------------------------------------------------------------
  // UI helpers
  // --------------------------------------------------------------------------

  Widget _adminShell(GoRouterState state, int index) {
    return AdminShellScreen(
      key: ValueKey<String>(state.uri.toString()),
      initialIndex: index,
    );
  }

  Widget _userShell(GoRouterState state, int index) {
    return UserShellScreen(
      key: ValueKey<String>(state.uri.toString()),
      initialIndex: index,
    );
  }

  // IMPORTANT: One builder for ALL /app/record routes (and its tabs)
  Widget _userRecordShell(GoRouterState state) {
    return UserShellScreen(
      key: ValueKey<String>(state.uri.toString()),
      initialIndex: 2,
    );
  }

  // --------------------------------------------------------------------------
  // Router
  // --------------------------------------------------------------------------

  late final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey, // <-- هنا الصحيح
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

      // ---------------- Auth ----------------
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/waiting-activation',
        builder: (context, state) => const WaitingActivationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/forgot-password/verify',
        builder: (context, state) {
          final email = state.uri.queryParameters['email']?.trim() ?? '';
          if (email.isEmpty) return const ForgotPasswordScreen();
          return ResetPasswordVerifyOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password/new',
        builder: (context, state) {
          final email = state.uri.queryParameters['email']?.trim() ?? '';
          final code = state.uri.queryParameters['code']?.trim() ?? '';
          if (email.isEmpty || code.isEmpty) {
            return const ForgotPasswordScreen();
          }
          return ResetPasswordNewPasswordScreen(email: email, code: code);
        },
      ),

      // ---------------- Admin (web-safe) ----------------
      GoRoute(
        path: '/admin',
        builder: (context, state) => _adminShell(state, 0),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => _adminShell(state, 1),
      ),
      GoRoute(
        path: '/admin/hospitals',
        builder: (context, state) => _adminShell(state, 2),
      ),
      GoRoute(
        path: '/admin/labs',
        builder: (context, state) => _adminShell(state, 3),
      ),
      GoRoute(
        path: '/admin/requests',
        builder: (context, state) => _adminShell(state, 4),
      ),
      GoRoute(
        path: '/admin/profile',
        builder: (context, state) => _adminShell(state, 5),
      ),

      // ---------------- App (User web-safe) ----------------
      GoRoute(
        path: '/app',
        builder: (context, state) => _userShell(state, 0),
        routes: [
          // ---------------- Doctor Scheduling ----------------
          GoRoute(
            path: 'doctor/scheduling',
            builder: (context, state) => const DoctorSchedulingSettingsScreen(),
            routes: [
              GoRoute(
                path: 'availability',
                builder: (context, state) => const DoctorAvailabilityScreen(),
              ),
              GoRoute(
                path: 'visit-types',
                builder: (context, state) => const DoctorVisitTypesScreen(),
              ),
              GoRoute(
                path: 'absences',
                builder: (context, state) => const DoctorAbsencesScreen(),
              ),
            ],
          ),

          // ---------------- Unified Record ----------------
          GoRoute(
            path: 'record',
            builder: (context, state) => _userRecordShell(state),
            routes: [
              GoRoute(
                path: 'orders/:orderId',
                builder: (context, state) {
                  final raw = state.pathParameters['orderId'];
                  final orderId = int.tryParse(raw ?? '');
                  if (orderId == null) {
                    return const Scaffold(
                      body: Center(child: Text('Invalid order id')),
                    );
                  }

                  final role =
                      (state.uri.queryParameters['role'] ?? 'patient').trim();

                  final patientIdRaw = state.uri.queryParameters['patientId'];
                  final patientId = int.tryParse(patientIdRaw ?? '');

                  final apptIdRaw = state.uri.queryParameters['appointmentId'];
                  final appointmentId = int.tryParse(apptIdRaw ?? '');

                  return OrderDetailsScreen(
                    role: role,
                    orderId: orderId,
                    doctorPatientId: (role == 'doctor') ? patientId : null,
                    appointmentId: appointmentId,
                  );
                },
              ),

              GoRoute(
                path: 'files',
                builder: (context, state) => _userRecordShell(state),
              ),
              GoRoute(
                path: 'prescripts',
                builder: (context, state) => _userRecordShell(state),
              ),
              GoRoute(
                path: 'adherence',
                builder: (context, state) => _userRecordShell(state),
              ),
              GoRoute(
                path: 'health-profile',
                builder: (context, state) => _userRecordShell(state),
              ),
            ],
          ),

          // ---------------- Hospitals ----------------
          GoRoute(
            path: 'hospitals',
            builder: (context, state) => _userShell(state, 3),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is! Map) return _userShell(state, 3);

                  final name = (extra['name'] ?? '').toString().trim();
                  final governorateRaw = extra['governorate'];
                  final int governorate =
                      governorateRaw is int
                          ? governorateRaw
                          : int.tryParse(governorateRaw?.toString() ?? '') ?? 0;

                  if (name.isEmpty || governorate == 0) {
                    return _userShell(state, 3);
                  }

                  return HospitalPublicDetailScreen(
                    name: name,
                    governorate: governorate,
                    governorateName: extra['governorateName']?.toString(),
                    address: extra['address']?.toString(),
                    latitude:
                        extra['latitude'] is double
                            ? extra['latitude'] as double
                            : double.tryParse(
                              extra['latitude']?.toString() ?? '',
                            ),
                    longitude:
                        extra['longitude'] is double
                            ? extra['longitude'] as double
                            : double.tryParse(
                              extra['longitude']?.toString() ?? '',
                            ),
                    specialty: extra['specialty']?.toString(),
                    contactInfo: extra['contactInfo']?.toString(),
                  );
                },
              ),
            ],
          ),

          // ---------------- Labs ----------------
          GoRoute(
            path: 'labs',
            builder: (context, state) => _userShell(state, 4),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is! Map) return _userShell(state, 4);

                  final name = (extra['name'] ?? '').toString().trim();
                  final governorateRaw = extra['governorate'];
                  final int governorate =
                      governorateRaw is int
                          ? governorateRaw
                          : int.tryParse(governorateRaw?.toString() ?? '') ?? 0;

                  if (name.isEmpty || governorate == 0) {
                    return _userShell(state, 4);
                  }

                  return LabPublicDetailScreen(
                    name: name,
                    governorate: governorate,
                    governorateName: extra['governorateName']?.toString(),
                    address: extra['address']?.toString(),
                    latitude:
                        extra['latitude'] is double
                            ? extra['latitude'] as double
                            : double.tryParse(
                              extra['latitude']?.toString() ?? '',
                            ),
                    longitude:
                        extra['longitude'] is double
                            ? extra['longitude'] as double
                            : double.tryParse(
                              extra['longitude']?.toString() ?? '',
                            ),
                    specialty: extra['specialty']?.toString(),
                    contactInfo: extra['contactInfo']?.toString(),
                  );
                },
              ),
            ],
          ),

          // ---------------- Account ----------------
          GoRoute(
            path: 'account',
            builder: (context, state) => _userShell(state, 5),
            routes: [
              GoRoute(
                path: 'patient-details',
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is Map) {
                    final token = (extra['token'] ?? '').toString();
                    final dynamic rawUserId = extra['userId'];
                    final int userId =
                        rawUserId is int
                            ? rawUserId
                            : int.tryParse(rawUserId?.toString() ?? '') ?? 0;

                    if (token.isNotEmpty && userId != 0) {
                      return PatientDetailsScreen(token: token, userId: userId);
                    }
                  }
                  return const UserShellScreen(initialIndex: 5);
                },
              ),
              GoRoute(
                path: 'doctor-details',
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is Map) {
                    final token = (extra['token'] ?? '').toString();
                    final dynamic rawUserId = extra['userId'];
                    final int userId =
                        rawUserId is int
                            ? rawUserId
                            : int.tryParse(rawUserId?.toString() ?? '') ?? 0;

                    if (token.isNotEmpty && userId != 0) {
                      return DoctorDetailsScreen(token: token, userId: userId);
                    }
                  }
                  return const UserShellScreen(initialIndex: 5);
                },
              ),
              GoRoute(
                path: 'deletion-status',
                builder:
                    (context, state) => const AccountDeletionStatusScreen(),
              ),
            ],
          ),

          // ---------------- appointments ----------------
          GoRoute(
            path: 'appointments',
            builder: (context, state) => _userShell(state, 1),
            routes: [
              GoRoute(
                path: 'book',
                builder: (context, state) => const DoctorSearchScreen(),
                routes: [
                  GoRoute(
                    path: ':doctorId',
                    builder: (context, state) {
                      final raw = state.pathParameters['doctorId'];
                      final doctorId = int.tryParse(raw ?? '');
                      if (doctorId == null) {
                        return const Scaffold(
                          body: Center(child: Text('Invalid doctor id')),
                        );
                      }

                      final extra = state.extra;
                      final doctorName =
                          (extra is Map && extra['doctorName'] != null)
                              ? extra['doctorName'].toString()
                              : 'طبيب';

                      final doctorSpecialty =
                          (extra is Map && extra['doctorSpecialty'] != null)
                              ? extra['doctorSpecialty'].toString()
                              : '';

                      return BookAppointmentScreen(
                        doctorId: doctorId,
                        doctorName: doctorName,
                        doctorSpecialty: doctorSpecialty,
                      );
                    },
                  ),
                ],
              ),
              // NEW: Doctor urgent requests list
              GoRoute(
                path: 'urgent-requests',
                builder: (context, state) => const DoctorUrgentRequestsScreen(),
              ),
            ],
          ),

          // inbox
          GoRoute(
            path: 'inbox',
            builder: (context, state) => const InboxScreen(),
          ),
        ],
      ),
    ],
  );

  void toggleTheme() {
    setState(() {
      themeMode =
          themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey, // <-- موجود عندك
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,

      // ---- RTL + Arabic ----
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
