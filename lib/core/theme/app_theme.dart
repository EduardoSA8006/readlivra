import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: brightness,
    ).copyWith(
      primary: isLight ? AppPalette.primary : AppPalette.primaryDark,
      onPrimary: Colors.white,
      secondary: AppPalette.secondary,
      onSecondary: Colors.white,
      tertiary: AppPalette.tertiary,
      onTertiary: Colors.white,
      surface: isLight ? AppPalette.lightSurface : AppPalette.darkSurface,
      surfaceContainer: isLight
          ? AppPalette.lightSurfaceContainer
          : AppPalette.darkSurfaceContainer,
      surfaceContainerHigh: isLight
          ? AppPalette.lightSurfaceContainerHigh
          : AppPalette.darkSurfaceContainerHigh,
      onSurface:
          isLight ? AppPalette.lightOnSurface : AppPalette.darkOnSurface,
      onSurfaceVariant: isLight
          ? AppPalette.lightOnSurfaceVariant
          : AppPalette.darkOnSurfaceVariant,
      outline: isLight ? AppPalette.lightOutline : AppPalette.darkOutline,
      error: AppPalette.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      scaffoldBackgroundColor:
          isLight ? AppPalette.lightBackground : AppPalette.darkBackground,
      textTheme: inter.copyWith(
        headlineMedium: inter.headlineMedium!.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          height: 1.2,
        ),
        titleLarge: inter.titleLarge!.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: inter.titleMedium!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyMedium: inter.bodyMedium!.copyWith(
          fontSize: 14,
          color: scheme.onSurface,
          height: 1.4,
        ),
        bodySmall: inter.bodySmall!.copyWith(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: inter.labelLarge!.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
    );
  }
}
