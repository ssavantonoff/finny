import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/finny_sleep_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    for (final (label, expected) in [
      ('Вернуться', false),
      ('Уложить спать', true),
    ]) {
      testWidgets('$label returns $expected without ending a day itself', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
        final primary = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Уложить спать'),
        );
        final secondary = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Вернуться'),
        );
        expect(primary.style!.backgroundColor!.resolve({}), AppColors.primary);
        expect(primary.style!.foregroundColor!.resolve({}), Colors.white);
        expect(primary.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(
          secondary.style!.foregroundColor!.resolve({}),
          AppColors.primaryDark,
        );
        expect(secondary.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(result, expected);
        expect(find.byType(FinnySleepDialog), findsNothing);
      });
    }
  }
}
