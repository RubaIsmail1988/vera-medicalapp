import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double? height;

  const AppLogo({super.key, this.width = 180, this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface, // ينسجم مع الثيم (فاتح/غامق)
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Image.asset(
        'assets/images/logo_black.png', // صورة واحدة فقط
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
