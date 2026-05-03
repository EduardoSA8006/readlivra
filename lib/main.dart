import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';

void main() {
  runApp(const ReadlivraApp());
}

class ReadlivraApp extends StatelessWidget {
  const ReadlivraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Readlivra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
