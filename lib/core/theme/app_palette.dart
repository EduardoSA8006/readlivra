import 'package:flutter/material.dart';

/// Raw color palette for the global app theme.
///
/// Brand identity is blue, but background surfaces stay deliberately neutral
/// (cool greys, near-black) so the screen never feels "blue tinted" — the
/// blue shows up on actions, accents and the hero gradient only.
class AppPalette {
  // Brand
  static const Color primary = Color(0xFF2E6CF6);
  static const Color primaryDark = Color(0xFF5685FA);
  static const Color secondary = Color(0xFFE0723A); // warm orange
  static const Color tertiary = Color(0xFF14B8A6); // teal accent
  static const Color danger = Color(0xFFB35454);

  // Light surfaces
  static const Color lightBackground = Color(0xFFF5F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHigh = Color(0xFFEEF1F5);
  static const Color lightOnSurface = Color(0xFF1B1F2A);
  static const Color lightOnSurfaceVariant = Color(0xFF6B707A);
  static const Color lightOutline = Color(0xFFE2E5EB);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF11131A);
  static const Color darkSurface = Color(0xFF1A1D27);
  static const Color darkSurfaceContainer = Color(0xFF22252F);
  static const Color darkSurfaceContainerHigh = Color(0xFF2B2F3B);
  static const Color darkOnSurface = Color(0xFFE7E9EE);
  static const Color darkOnSurfaceVariant = Color(0xFF9CA1AB);
  static const Color darkOutline = Color(0xFF2D313C);

  /// Hero gradient used by "Continue lendo" and the streak card. The pair
  /// works on both modes because both tones are well above the dark surface.
  static const heroGradient = <Color>[Color(0xFF1F4FCC), Color(0xFF3D85F7)];
}
