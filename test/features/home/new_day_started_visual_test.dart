import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pet = Pet(
    profileId: 1,
    name: 'Финни',
    colorId: 'mint',
    patternId: 'stripes',
    developmentStage: 2,
    growthPoints: 0,
    satiety: 80,
    care: 80,
    mood: 80,
  );
  final period = GamePeriod(
    id: 3,
    profileId: 1,
    definitionId: 'period_3',
    periodNumber: 3,
    startWalletBalance: 70,
    baseIncome: 500,
    extraIncome: 0,
    plannedNeed: 0,
    plannedWant: 0,
    plannedSavings: 0,
    plannedFree: 570,
    actualNeed: 0,
    actualWant: 0,
    actualSavings: 0,
    requiredCheckpoints: const [],
    resolvedCheckpoints: const [],
    growthPointsEarned: 0,
    status: GamePeriodStatus.planning,
    createdAt: DateTime.utc(2026),
  );
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('New Day shows canonical Day 3 amounts and Finny at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: NewDayStartedScreen(period: period, pet: pet),
        ),
      );
      expect(find.text('День 3'), findsOneWidget);
      expect(find.text('Сегодня доступно'), findsOneWidget);
      expect(find.text('570'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('Составить план'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  FinnyVisual.assetForPet(pet),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
