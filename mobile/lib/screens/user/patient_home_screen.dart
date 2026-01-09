import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientHomeScreen extends StatefulWidget {
  final int userId;
  final String token;

  const PatientHomeScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  String? userName;
  bool loadingName = true;

  @override
  void initState() {
    super.initState();
    loadUserName();
  }

  Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('currentUserName');

    if (!mounted) return;

    setState(() {
      userName = savedName;
      loadingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final greeting =
        (userName != null && userName!.trim().isNotEmpty)
            ? 'أهلاً بك يا ${userName!}'
            : 'أهلاً بك';

    // ملاحظة: لا Scaffold هنا لأن UserShellScreen هو من يوفّر Scaffold
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يمكنك من هنا متابعة حالتك الطبية وحجوزاتك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
