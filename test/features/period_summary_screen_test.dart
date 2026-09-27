import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/features/period_summary/period_summary_controller.dart';
import 'package:finny/features/period_summary/period_summary_screen.dart';
import 'package:finny/features/progress/progress_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/period_summary.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

class _StaticSummaryController extends PeriodSummaryController {
  _StaticSummaryController(this.initial);
  final PeriodSummaryViewState initial;

  @override
  PeriodSummaryViewState build() => initial;

  @override
  Future<void> load() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(finder, findsOneWidget);
  }

  test('summary observations follow actual values without a fixed verdict', () {
    const higherWantAndSavings = PeriodSummary(
      openingWalletBalance: 0,
      baseIncome: 500,
      startingBudget: 500,
      additionalIncome: 50,
      plannedNeed: 100,
      plannedWant: 100,
      plannedSavings: 100,
      plannedRemainder: 200,
      factNeed: 100,
      factWant: 150,
      factSavings: 130,
      factRemainder: 170,
    );
    expect(summaryObservations(higherWantAndSavings), [
      'На «Хочу» ушло больше, чем было в плане.',
      'В копилку получилось отложить больше, чем планировалось.',
    ]);
    const matched = PeriodSummary(
      openingWalletBalance: 0,
      baseIncome: 500,
      startingBudget: 500,
      additionalIncome: 0,
      plannedNeed: 100,
      plannedWant: 100,
      plannedSavings: 100,
      plannedRemainder: 200,
      factNeed: 100,
      factWant: 100,
      factSavings: 100,
      factRemainder: 200,
    );
    expect(summaryObservations(matched), [
      'План и фактические траты за день совпали.',
    ]);
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('completed period summary renders Plan and Fact at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = PeriodSummaryReady(
        period: GamePeriod(
          id: 1,
          profileId: 1,
          definitionId: 'period_1',
          periodNumber: 1,
          startWalletBalance: 0,
          baseIncome: 500,
          extraIncome: 0,
          plannedNeed: 100,
          plannedWant: 100,
          plannedSavings: 100,
          plannedFree: 200,
          actualNeed: 80,
          actualWant: 120,
          actualSavings: 100,
          requiredCheckpoints: const [],
          resolvedCheckpoints: const [],
          endWalletBalance: 200,
          growthPointsEarned: 0,
          status: GamePeriodStatus.completed,
          createdAt: DateTime.utc(2026, 1, 1),
          completedAt: DateTime.utc(2026, 1, 2),
        ),
        summary: const PeriodSummary(
          openingWalletBalance: 0,
          baseIncome: 500,
          startingBudget: 500,
          additionalIncome: 0,
          plannedNeed: 100,
          plannedWant: 100,
          plannedSavings: 100,
          plannedRemainder: 200,
          factNeed: 80,
          factWant: 120,
          factSavings: 100,
          factRemainder: 200,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            periodSummaryControllerProvider.overrideWith(
              () => _StaticSummaryController(state),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PeriodSummaryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('День 1 завершён!'), findsOneWidget);
      expect(find.text('План'), findsOneWidget);
      expect(find.text('Факт'), findsOneWidget);
      expect(find.text('Нужно'), findsOneWidget);
      expect(find.text('Хочу'), findsOneWidget);
      expect(find.text('Копилка'), findsOneWidget);
      expect(find.text('Свободно'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('summary-home')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('summary-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (day, savedStage, summaryStage) in [
    (2, 2, 1),
    (5, 3, 2),
    (4, 2, 2),
  ]) {
    testWidgets(
      'Day $day Summary shows stage $summaryStage and Growth retains saved stage $savedStage',
      (tester) async {
        final database = createTestDatabase();
        final games = SqliteGameRepository(database);
        await tester.runAsync(() async {
          final db = await database.database;
          await db.insert('profiles', {
            'id': 1,
            'game_name': 'Игрок',
            'profile_type': 'NORMAL',
            'onboarding_completed': 1,
            'created_at': DateTime.utc(2026).toIso8601String(),
          });
          await games.savePet(
            Pet(
              profileId: 1,
              name: 'Искорка',
              colorId: 'mint',
              patternId: 'spots',
              developmentStage: savedStage,
              growthPoints: 200,
              satiety: 80,
              care: 80,
              mood: 80,
            ),
          );
        });
        final state = PeriodSummaryReady(
          period: GamePeriod(
            id: day,
            profileId: 1,
            definitionId: 'period_$day',
            periodNumber: day,
            startWalletBalance: 0,
            baseIncome: 500,
            extraIncome: 0,
            plannedNeed: 100,
            plannedWant: 100,
            plannedSavings: 100,
            plannedFree: 200,
            actualNeed: 100,
            actualWant: 100,
            actualSavings: 100,
            requiredCheckpoints: const [],
            resolvedCheckpoints: const [],
            endWalletBalance: 200,
            growthPointsEarned: 0,
            status: GamePeriodStatus.completed,
            createdAt: DateTime.utc(2026, 1, day),
          ),
          summary: const PeriodSummary(
            openingWalletBalance: 0,
            baseIncome: 500,
            startingBudget: 500,
            additionalIncome: 0,
            plannedNeed: 100,
            plannedWant: 100,
            plannedSavings: 100,
            plannedRemainder: 200,
            factNeed: 100,
            factWant: 100,
            factSavings: 100,
            factRemainder: 200,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            gameRepositoryProvider.overrideWithValue(games),
            periodSummaryControllerProvider.overrideWith(
              () => _StaticSummaryController(state),
            ),
          ],
        );
        container.read(activeProfileIdProvider.notifier).setActiveProfileId(1);
        addTearDown(() async {
          container.dispose();
          await database.close();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const PeriodSummaryScreen(),
            ),
          ),
        );
        await waitFor(tester, find.byKey(const Key('summary-finny-art')));
        final summaryPreview = tester.widget<FinnyPreview>(
          find.byKey(const Key('summary-finny-art')),
        );
        expect(summaryPreview.name, 'Искорка');
        expect(summaryPreview.colorId, 'mint');
        expect(summaryPreview.patternId, 'spots');
        expect(summaryPreview.developmentStage, summaryStage);
        expect(
          (tester
                      .widget<Image>(
                        find.descendant(
                          of: find.byKey(const Key('summary-finny-art')),
                          matching: find.byType(Image),
                        ),
                      )
                      .image
                  as AssetImage)
              .assetName,
          'assets/images/finny/stage$summaryStage/mint_spots.png',
        );

        if (day == 2 || day == 5) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.light,
                home: ProgressScreen(completedDay: day),
              ),
            ),
          );
          await waitFor(tester, find.byType(Image));
          expect(find.text('Этап $savedStage из 3'), findsOneWidget);
          expect(
            (tester.widget<Image>(find.byType(Image).first).image as AssetImage)
                .assetName,
            'assets/images/finny/stage$savedStage/mint_spots.png',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('carried bowl expense and savings withdrawal are explicit', (
    tester,
  ) async {
    final state = PeriodSummaryReady(
      period: GamePeriod(
        id: 4,
        profileId: 1,
        definitionId: 'period_4',
        periodNumber: 4,
        startWalletBalance: 80,
        baseIncome: 0,
        extraIncome: 0,
        plannedNeed: 0,
        plannedWant: 0,
        plannedSavings: 50,
        plannedFree: 30,
        actualNeed: 120,
        actualWant: 0,
        actualSavings: 50,
        requiredCheckpoints: const [],
        resolvedCheckpoints: const [],
        endWalletBalance: 0,
        growthPointsEarned: 0,
        status: GamePeriodStatus.completed,
        createdAt: DateTime.utc(2026, 1, 4),
      ),
      summary: const PeriodSummary(
        openingWalletBalance: 80,
        baseIncome: 0,
        startingBudget: 80,
        additionalIncome: 0,
        plannedNeed: 0,
        plannedWant: 0,
        plannedSavings: 50,
        plannedRemainder: 30,
        factNeed: 120,
        factWant: 0,
        factSavings: 50,
        factRemainder: 0,
        unexpectedNeed: 120,
        carriedUnexpectedNeed: true,
        savingsWithdrawn: 40,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          periodSummaryControllerProvider.overrideWith(
            () => _StaticSummaryController(state),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PeriodSummaryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Перенесённая нужная трата: Новая миска — 120 монет'),
      findsOneWidget,
    );
    expect(find.text('Из копилки использовано: 40 монет'), findsOneWidget);
    expect(find.text('50'), findsNWidgets(2));
  });
}
