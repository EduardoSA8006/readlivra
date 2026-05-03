import 'package:flutter_test/flutter_test.dart';

import 'package:readlivra/main.dart';

void main() {
  testWidgets('HomeScreen renders greeting and continue reading', (tester) async {
    await tester.pumpWidget(const ReadlivraApp());

    expect(find.text('Olá, Eduardo'), findsOneWidget);
    expect(find.text('Continue lendo'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
  });
}
