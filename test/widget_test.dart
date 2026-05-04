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

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Estatísticas'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('Library tab shows empty state when no books', (tester) async {
    await tester.pumpWidget(await _harness());
    await tester.pump();

    await tester.tap(find.text('Biblioteca'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sua biblioteca está vazia.'), findsOneWidget);
  });
}
