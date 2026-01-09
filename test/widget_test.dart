import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofi/main.dart';

void main() {
  testWidgets(
      'Kliknięcie "Rozpocznij Teraz" przenosi do formularza rejestracji',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    final mainButton = find.widgetWithText(ElevatedButton, 'Rozpocznij Teraz');
    await tester.tap(mainButton);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget,
        reason: "Brak pola Email na ekranie rejestracji");

    expect(find.widgetWithText(TextFormField, 'Hasło'), findsAtLeastNWidgets(1),
        reason: "Brak pola Hasło na ekranie rejestracji");
  });
}
