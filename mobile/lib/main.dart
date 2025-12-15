import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

// Auth
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/waiting_activation_screen.dart';
import 'screens/auth/forgot_password_screen.dart';

// Shells
import 'screens/user/user_shell_screen.dart';
import 'screens/admin/admin_shell_screen.dart';

// System
import 'screens/system/splash_screen.dart';

// شاشات قديمة
import 'screens/user/patient_home_screen.dart';
import 'screens/user/doctor_home_screen.dart';
import 'screens/admin/hospital_list_screen.dart';
import 'screens/admin/lab_list_screen.dart';
//phase c
import 'screens/doctor/doctor_scheduling_settings_screen.dart';

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

  void toggleTheme() {
    setState(() {
      themeMode =
          themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      themeMode: themeMode,

      // Animated theme transition
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      // Splash بدل StartScreen
      home: const SplashScreen(),

      routes: {
        // Auth
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/waiting-activation': (context) => const WaitingActivationScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),

        // Admin
        '/admin-home': (context) => const AdminShellScreen(),

        // User Shell
        '/user-shell': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;

          final role = args?['role'] as String? ?? 'patient';
          final userId = args?['userId'] as int?;
          final token = args?['token'] as String?;

          if (userId == null || token == null) {
            return const LoginScreen();
          }

          return UserShellScreen(role: role, userId: userId, token: token);
        },

        // Legacy routes
        '/patient-home': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return PatientHomeScreen(
            userId: args['userId'] as int,
            token: args['token'] as String,
          );
        },
        '/doctor-home': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return DoctorHomeScreen(
            userId: args['userId'] as int,
            token: args['token'] as String,
          );
        },
        '/doctor-scheduling-settings':
            (context) => const DoctorSchedulingSettingsScreen(),
        '/hospital-list': (context) => const HospitalListScreen(),
        '/lab-list': (context) => const LabListScreen(),
      },
    );
  }
}
