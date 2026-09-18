import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

class _AtmosphereProfiles implements ProfileRepository {
  _AtmosphereProfiles(this.profile);
  final Profile profile;

  @override
  Future<Profile> create(Profile profile) async => profile;
  @override
  Future<List<Profile>> findAll() async => [profile];
  @override
  Future<Profile?> findById(int id) async => profile;
  @override
  Future<void> update(Profile profile) async {}
}

class _AtmosphereGames extends SqliteGameRepository {
  _AtmosphereGames(super.database, this.pet, this.gameState, this.period);

  Pet pet;
  GameState gameState;
  GamePeriod? period;
  int petUsage = 0;
  int playUsage = 0;

  @override
  Future<GameState?> getGameState(int profileId) async => gameState;
  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async =>
      period == null ? const [] : [period!];
  @override
  Future<Pet?> getPet(int profileId) async => pet;
  @override
  Future<int> getPetDailyUsageCount({
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
  }) async {
    if (actionId == FreePetInteraction.pet.actionId) return petUsage;
    if (actionId == FreePetInteraction.play.actionId) return playUsage;
    return 0;
  }
}

void main() {
  group('PetStatIndicator unit tests', () {
    test('color thresholds: <=39 red, <=69 yellow, >=70 green', () {
      expect(PetStatIndicator.statColor(0), PetStatIndicator.red);
      expect(PetStatIndicator.statColor(39), PetStatIndicator.red);
      expect(PetStatIndicator.statColor(40), PetStatIndicator.yellow);
      expect(PetStatIndicator.statColor(69), PetStatIndicator.yellow);
      expect(PetStatIndicator.statColor(70), PetStatIndicator.green);
      expect(PetStatIndicator.statColor(100), PetStatIndicator.green);
    });

    testWidgets('renders progress bar and label without raw numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetStatIndicator(
              label: 'Сытость',
              value: 85,
              barKey: Key('test-bar'),
            ),
          ),
        ),
      );
      expect(find.text('Сытость'), findsOneWidget);
      expect(find.byKey(const Key('test-bar')), findsOneWidget);
      expect(find.text('85'), findsNothing);
      expect(find.text('85%'), findsNothing);
      expect(find.text('85/100'), findsNothing);
    });
  });

  group('HomeScreen atmosphere and interactions', () {
    testWidgets('renders Pet, wallet, stat indicators, day status, today card and goal', (
      tester,
    ) async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final profile = Profile(
        id: 1,
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final pet = const Pet(
        profileId: 1,
        name: 'Финни',
        colorId: 'purple',
        patternId: 'spots',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 80,
        care: 60,
        mood: 30,
      );
      final gameState = GameState(
        profileId: 1,
        walletBalance: 350,
        currentPeriod: 1,
        savedAmount: 150,
        activeGoalId: 'goal_bike',
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final period = GamePeriod(
        id: 10,
        profileId: 1,
        definitionId: 'period_1',
        periodNumber: 1,
        startWalletBalance: 500,
        baseIncome: 500,
        extraIncome: 0,
        plannedNeed: 200,
        plannedWant: 100,
        plannedSavings: 100,
        plannedFree: 100,
        actualNeed: 50,
        actualWant: 0,
        actualSavings: 0,
        requiredCheckpoints: const ['financial_task', 'savings_decision'],
        resolvedCheckpoints: const ['financial_task'],
        growthPointsEarned: 0,
        status: GamePeriodStatus.active,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final goal = const SavingsGoal(
        id: 'goal_bike',
        name: 'Велосипед',
        price: 500,
        description: 'Классный велосипед',
        rewardAssetId: 'bike',
      );

      final profiles = _AtmosphereProfiles(profile);
      final games = _AtmosphereGames(database, pet, gameState, period);
      final content = TestContentRepository(
        [
          const PeriodDefinition(
            id: 'period_1',
            number: 1,
            title: 'Знакомство с бюджетом',
            baseIncome: 500,
            requiredCheckpoints: ['financial_task', 'savings_decision'],
          ),
        ],
        goals: [goal],
      );

      final container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWith(
            () => _ActiveProfileMock(1),
          ),
          profileRepositoryProvider.overrideWithValue(profiles),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Wallet in AppBar
      expect(find.byKey(const Key('home-wallet')), findsOneWidget);
      expect(find.text('350 🪙'), findsOneWidget);

      // Pet name
      expect(find.byKey(const Key('home-pet-name')), findsOneWidget);
      expect(find.text('Финни'), findsOneWidget);

      // 3 stat bars
      expect(find.byKey(const Key('home-stat-satiety-bar')), findsOneWidget);
      expect(find.byKey(const Key('home-stat-care-bar')), findsOneWidget);
      expect(find.byKey(const Key('home-stat-mood-bar')), findsOneWidget);

      // Free interactions visible
      expect(find.byKey(const Key('home-free-pet')), findsOneWidget);
      expect(find.byKey(const Key('home-free-play')), findsOneWidget);
      expect(find.text('Погладить'), findsOneWidget);
      expect(find.text('Поиграть'), findsOneWidget);

      // Day status card & view plan button (active status)
      expect(find.byKey(const Key('home-day-status')), findsOneWidget);
      expect(find.byKey(const Key('home-view-plan')), findsOneWidget);
      expect(find.text('Посмотреть план'), findsOneWidget);

      // Today card with checkpoints
      expect(find.byKey(const Key('home-today-card')), findsOneWidget);
      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('Задание'), findsOneWidget);
      expect(find.text('Накопления'), findsOneWidget);

      // Active savings goal card
      expect(find.byKey(const Key('home-savings-goal')), findsOneWidget);
      expect(find.text('Велосипед'), findsOneWidget);
      expect(find.text('150/500 🪙'), findsOneWidget);
    });

    testWidgets('free interaction changes button state to used today and disabled', (
      tester,
    ) async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final profile = Profile(
        id: 1,
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final pet = const Pet(
        profileId: 1,
        name: 'Финни',
        colorId: 'purple',
        patternId: 'spots',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 80,
        care: 60,
        mood: 30,
      );
      final gameState = GameState(
        profileId: 1,
        walletBalance: 350,
        currentPeriod: 1,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final period = GamePeriod(
        id: 10,
        profileId: 1,
        definitionId: 'period_1',
        periodNumber: 1,
        startWalletBalance: 500,
        baseIncome: 500,
        extraIncome: 0,
        plannedNeed: 200,
        plannedWant: 100,
        plannedSavings: 100,
        plannedFree: 100,
        actualNeed: 0,
        actualWant: 0,
        actualSavings: 0,
        requiredCheckpoints: const [],
        resolvedCheckpoints: const [],
        growthPointsEarned: 0,
        status: GamePeriodStatus.active,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final games = _AtmosphereGames(database, pet, gameState, period);
      // Mark pet action as already used today (1)
      games.petUsage = 1;

      final container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWith(
            () => _ActiveProfileMock(1),
          ),
          profileRepositoryProvider.overrideWithValue(
            _AtmosphereProfiles(profile),
          ),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(
            TestContentRepository([
              const PeriodDefinition(
                id: 'period_1',
                number: 1,
                title: 'Период 1',
                baseIncome: 500,
                requiredCheckpoints: [],
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pet button should show checkmark and be disabled
      final petBtnFinder = find.byKey(const Key('home-free-pet'));
      expect(petBtnFinder, findsOneWidget);
      expect(find.text('Погладить ✓'), findsOneWidget);
      final buttonWidget = tester.widget<FilledButton>(petBtnFinder);
      expect(buttonWidget.onPressed, isNull);

      // Play button is not used yet, so it is enabled
      final playBtnFinder = find.byKey(const Key('home-free-play'));
      expect(playBtnFinder, findsOneWidget);
      expect(find.text('Поиграть'), findsOneWidget);
      final playWidget = tester.widget<FilledButton>(playBtnFinder);
      expect(playWidget.onPressed, isNotNull);
    });
  });
}

class _ActiveProfileMock extends ActiveProfileIdController {
  _ActiveProfileMock(this.id);
  final int id;
  @override
  int? build() => id;
}
