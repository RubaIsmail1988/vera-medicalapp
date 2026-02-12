import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double? height;
  final bool framed;

  const AppLogo({super.key, this.width = 180, this.height, this.framed = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final logoPath =
        isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png';

    final image = Image.asset(
      logoPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
    );

    if (!framed) return image;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: image,
    );
  }
}
