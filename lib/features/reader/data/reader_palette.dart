import 'package:flutter/material.dart';

import 'models/reading_preferences.dart';

/// Palette dedicated to the reader (book content view). Insulated from the
/// global app theme on purpose: the reader has its own light/sepia/dark
/// modes selected by the user via the reading preferences sheet.
class ReaderPalette {
  const ReaderPalette({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.outline,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color outline;

  /// Bright cream background, dark inky text — the comfortable default.
  static const light = ReaderPalette(
    background: Color(0xFFFAF6F0),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F1B2E),
    textSecondary: Color(0xFF6B6478),
    accent: Color(0xFFE0723A),
    outline: Color(0xFFEDE7DD),
  );

  /// Warm paper tone with brown ink — classic reader setup.
  static const sepia = ReaderPalette(
    background: Color(0xFFF4ECD8),
    surface: Color(0xFFFAF3DD),
    textPrimary: Color(0xFF3A2E1F),
    textSecondary: Color(0xFF74614A),
    accent: Color(0xFFB87333),
    outline: Color(0xFFE5D9BE),
  );

  /// Low-light mode with warm off-white type.
  static const dark = ReaderPalette(
    background: Color(0xFF14161B),
    surface: Color(0xFF1F2229),
    textPrimary: Color(0xFFE2E0D8),
    textSecondary: Color(0xFFA0A39B),
    accent: Color(0xFFE0723A),
    outline: Color(0xFF2C313C),
  );

  static ReaderPalette of(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.light:
        return light;
      case ReadingTheme.sepia:
        return sepia;
      case ReadingTheme.dark:
        return dark;
    }
  }
}
