import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/app/main_shell.dart';
import 'package:readlivra/core/storage/storage_providers.dart';
import 'package:readlivra/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _harness() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final tempDir = Directory.systemTemp.createTempSync('readlivra_test_');

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => prefs),
      booksDirectoryProvider.overrideWith((ref) async => tempDir),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets('MainShell renders bottom navigation', (tester) async {
    await tester.pumpWidget(await _harness());
    await tester.pump();

    // Each label is rendered twice: in the AppBar title and in the bottom nav.
    // Home tab shows the time-based greeting in the AppBar instead of "Início",
    // so the label appears only in the bottom nav.
    expect(find.text('Início'), findsAtLeastNWidgets(1));
    expect(find.text('Biblioteca'), findsAtLeastNWidgets(1));
    expect(find.text('Estatísticas'), findsAtLeastNWidgets(1));
    expect(find.text('Perfil'), findsAtLeastNWidgets(1));
  });

  testWidgets('Library tab shows empty state when no books', (tester) async {
    await tester.pumpWidget(await _harness());
    await tester.pump();

    await tester.tap(find.text('Biblioteca'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sua biblioteca está vazia'), findsOneWidget);
  });
}
