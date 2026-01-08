import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoctorHomeScreen extends StatefulWidget {
  final int userId;
  final String token;

  const DoctorHomeScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
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
    if (loadingName) {
      return const Center(child: CircularProgressIndicator());
    }

    final greeting =
        (userName != null && userName!.trim().isNotEmpty)
            ? 'أهلاً بك يا ${userName!}'
            : 'أهلاً بك';

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
                'يمكنك إدارة الإضبارة الطبية، متابعة المواعيد، ومراجعة الملفات عبر التبويبات بالأسفل.\n'
                'إعدادات الحساب والجدولة وطلبات الحذف  ضمن تبويب "الحساب".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.70),
                ),
              ),

              const SizedBox(height: 24),

              // اختياري: Shortcut مفيد
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/app/record'),
                  icon: const Icon(Icons.folder_shared),
                  label: const Text('فتح الإضبارة الطبية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
