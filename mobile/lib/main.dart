import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

//aAppointment
import 'screens/user/appointments/book_appointment_screen.dart';
import 'screens/user/appointments/doctor_search_screen.dart';
import 'utils/ui_helpers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class MyAppState extends State<MyApp> {
  ThemeMode themeMode = ThemeMode.dark;

  late final GoRouter router = GoRouter(
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
        builder:
            (context, state) => AdminShellScreen(
              key: ValueKey<String>(state.uri.path),
              initialIndex: 0,
            ),
      ),
      GoRoute(
        path: '/admin/users',
        builder:
            (context, state) => AdminShellScreen(
              key: ValueKey<String>(state.uri.path),
              initialIndex: 1,
            ),
      ),
      GoRoute(
        path: '/admin/hospitals',
        builder:
            (context, state) => AdminShellScreen(
              key: ValueKey<String>(state.uri.path),
              initialIndex: 2,
            ),
      ),
      GoRoute(
        path: '/admin/labs',
        builder:
            (context, state) => AdminShellScreen(
              key: ValueKey<String>(state.uri.path),
              initialIndex: 3,
            ),
      ),
      GoRoute(
        path: '/admin/requests',
        builder:
            (context, state) => AdminShellScreen(
              key: ValueKey<String>(state.uri.path),
              initialIndex: 4,
            ),
      ),
      GoRoute(
        path: '/admin/profile',
        builder:
            (context, state) => AdminShellScreen(
              key: ValueKey<String>(state.uri.path),
              initialIndex: 5,
            ),
      ),

      // ---------------- App (User web-safe) ----------------
      GoRoute(
        path: '/app',
        builder:
            (context, state) => UserShellScreen(
              key: ValueKey<String>(state.uri.path),
              initialIndex: 0,
            ),
        routes: [
          // ---------------- Doctor Scheduling (Phase C) ----------------
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
            builder:
                (context, state) => UserShellScreen(
                  key: ValueKey<String>(state.uri.path),
                  initialIndex: 1,
                ),
            routes: [
              // تفاصيل الطلب
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

                  final extra = state.extra;
                  final role =
                      (extra is Map && extra['role'] != null)
                          ? extra['role'].toString()
                          : 'patient';

                  final patientIdRaw = state.uri.queryParameters['patientId'];
                  final patientId = int.tryParse(patientIdRaw ?? '');

                  return OrderDetailsScreen(
                    role: role,
                    orderId: orderId,
                    doctorPatientId: (role == 'doctor') ? patientId : null,
                  );
                },
              ),

              // Tabs routes (UI فقط)
              GoRoute(
                path: 'files',
                builder:
                    (context, state) => UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 1,
                    ),
              ),
              GoRoute(
                path: 'prescripts',
                builder:
                    (context, state) => UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 1,
                    ),
              ),
              GoRoute(
                path: 'adherence',
                builder:
                    (context, state) => UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 1,
                    ),
              ),

              // ---------------- NEW: Health Profile Tab ----------------
              GoRoute(
                path: 'health-profile',
                builder:
                    (context, state) => UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 1,
                    ),
              ),
            ],
          ),

          // ---------------- Hospitals ----------------
          GoRoute(
            path: 'hospitals',
            builder:
                (context, state) => UserShellScreen(
                  key: ValueKey<String>(state.uri.path),
                  initialIndex: 2,
                ),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (context, state) {
                  final extra = state.extra;

                  if (extra is! Map) {
                    return UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 2,
                    );
                  }

                  final name = (extra['name'] ?? '').toString().trim();
                  final governorateRaw = extra['governorate'];

                  final int governorate =
                      governorateRaw is int
                          ? governorateRaw
                          : int.tryParse(governorateRaw?.toString() ?? '') ?? 0;

                  if (name.isEmpty || governorate == 0) {
                    return UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 2,
                    );
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
            builder:
                (context, state) => UserShellScreen(
                  key: ValueKey<String>(state.uri.path),
                  initialIndex: 3,
                ),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (context, state) {
                  final extra = state.extra;

                  if (extra is! Map) {
                    return UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 3,
                    );
                  }

                  final name = (extra['name'] ?? '').toString().trim();
                  final governorateRaw = extra['governorate'];

                  final int governorate =
                      governorateRaw is int
                          ? governorateRaw
                          : int.tryParse(governorateRaw?.toString() ?? '') ?? 0;

                  if (name.isEmpty || governorate == 0) {
                    return UserShellScreen(
                      key: ValueKey<String>(state.uri.path),
                      initialIndex: 3,
                    );
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
            builder:
                (context, state) => UserShellScreen(
                  key: ValueKey<String>(state.uri.path),
                  initialIndex: 4,
                ),
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
                  return const UserShellScreen(initialIndex: 4);
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
                  return const UserShellScreen(initialIndex: 4);
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
            builder:
                (context, state) => UserShellScreen(
                  key: ValueKey<String>(state.uri.path),
                  initialIndex: 5,
                ),
            routes: [
              // /app/appointments/book
              GoRoute(
                path: 'book',
                builder: (context, state) => const DoctorSearchScreen(),
                routes: [
                  // /app/appointments/book/:doctorId
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
            ],
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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
