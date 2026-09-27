import 'package:finny/features/progress/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final day in [2, 5]) {
    for (final size in [const Size(360, 800), const Size(393, 852)]) {
      testWidgets(
        'Day $day progress routes to ${day == 5 ? 'finale' : 'home'} at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
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
          expect(find.text('Этап ${day == 5 ? 3 : 2} из 3'), findsOneWidget);
          final label = day == 5 ? 'Посмотреть итоги' : 'Продолжить';
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(
            find.text(day == 5 ? 'Финал открыт' : 'Дом открыт'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
