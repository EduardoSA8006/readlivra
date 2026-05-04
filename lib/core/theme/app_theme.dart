import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _seed = Color(0xFF5C4B8A);
  static const Color background = Color(0xFFFAF6F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F1B2E);
  static const Color textSecondary = Color(0xFF6B6478);
  static const Color accent = Color(0xFFE0723A);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: surface,
      onSurface: textPrimary,
      secondary: accent,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final interTextTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: interTextTheme.copyWith(
        headlineMedium: interTextTheme.headlineMedium!.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
        ),
        titleLarge: interTextTheme.titleLarge!.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: interTextTheme.titleMedium!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: interTextTheme.bodyMedium!.copyWith(
          fontSize: 14,
          color: textPrimary,
          height: 1.4,
        ),
        bodySmall: interTextTheme.bodySmall!.copyWith(
          fontSize: 12,
          color: textSecondary,
        ),
        labelLarge: interTextTheme.labelLarge!.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
