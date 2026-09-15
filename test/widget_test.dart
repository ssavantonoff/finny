import 'package:finny/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigation foundation opens feature routes', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinnyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать в Finny'), findsOneWidget);

    await tester.tap(find.text('Бюджет'));
    await tester.pumpAndSettle();

    expect(
      find.text('Планирование нужного, желаемого и накоплений.'),
      findsOneWidget,
    );
  });
}
