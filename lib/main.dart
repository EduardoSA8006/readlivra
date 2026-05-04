import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/main_shell.dart';
import 'core/theme/app_theme.dart';

void main() {
  // Fonts are bundled under assets/google_fonts/ — refuse runtime HTTP
  // fetching so the app behaves identically online and offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: ReadlivraApp()));
}

class ReadlivraApp extends StatelessWidget {
  const ReadlivraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Readlivra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const MainShell(),
    );
  }
}
