import 'package:finny/features/progress/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final day in [2, 5]) {
    testWidgets('Day $day progress routes to ${day == 5 ? 'finale' : 'home'}', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/progress',
        routes: [
          GoRoute(
            path: '/progress',
            builder: (_, _) => ProgressScreen(completedDay: day),
          ),
          GoRoute(
            path: '/finale',
            builder: (_, _) => const Scaffold(body: Text('Финал открыт')),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Дом открыт')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Финни вырос!'), findsOneWidget);
      expect(find.text('Этап ${day == 5 ? 3 : 2}'), findsOneWidget);
      final label = day == 5 ? 'Посмотреть итоги' : 'На главную';
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        find.text(day == 5 ? 'Финал открыт' : 'Дом открыт'),
        findsOneWidget,
      );
    });
  }
}
