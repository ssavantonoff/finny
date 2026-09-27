import 'package:finny/features/home/finny_sleep_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (label, expected) in [
    ('Вернуться', false),
    ('Уложить спать', true),
  ]) {
    testWidgets('$label returns $expected without ending a day itself', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const FinnySleepDialog(),
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.text('Финни готов отдыхать'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(result, expected);
      expect(find.byType(FinnySleepDialog), findsNothing);
    });
  }
}
