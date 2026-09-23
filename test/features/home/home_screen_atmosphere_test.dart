import '../../helpers/campaign_only_lifecycle_service.dart';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
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
import 'package:finny/models/story_event.dart';
import 'package:finny/services/story_event_service.dart';
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
  List<GamePeriod>? periodsOverride;
  int petUsage = 0;
  Duration usageReadDelay = Duration.zero;
  String? failingUsageActionId;

  @override
  Future<GameState?> getGameState(int profileId) async => gameState;
  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async =>
      periodsOverride ?? (period == null ? const [] : [period!]);
  @override
  Future<Pet?> getPet(int profileId) async => pet;
  @override
  Future<int> getPetDailyUsageCount({
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
  }) async {
    if (usageReadDelay != Duration.zero) {
      await Future<void>.delayed(usageReadDelay);
    }
    if (actionId == failingUsageActionId) {
      throw StateError('usage read failed');
    }
    if (actionId == FreePetInteraction.pet.actionId) return petUsage;
    return 0;
  }
}

class _NoopStoryEventService extends StoryEventService {
  _NoopStoryEventService(super.port, super.content);

  @override
  Future<StoryEventSnapshot?> loadDay3Bowl({required int profileId}) async =>
      null;
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

    testWidgets('renders progress bar and label without raw numbers', (
      tester,
    ) async {
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

    testWidgets('completed five-day campaign never suggests Day 6', (
      tester,
    ) async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final profile = Profile(
        id: 1,
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      );
      const pet = Pet(
        profileId: 1,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 3,
        growthPoints: 300,
        satiety: 80,
        care: 80,
        mood: 80,
      );
      final gameState = GameState(
        profileId: 1,
        walletBalance: 200,
        currentPeriod: 5,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026),
      );
      final periods = List<GamePeriod>.generate(5, (index) {
        final day = index + 1;
        return GamePeriod(
          id: day,
          profileId: 1,
          definitionId: 'period_$day',
          periodNumber: day,
          startWalletBalance: 500,
          baseIncome: 500,
          extraIncome: 0,
          plannedNeed: 0,
          plannedWant: 0,
          plannedSavings: 0,
          plannedFree: 500,
          actualNeed: 0,
          actualWant: 0,
          actualSavings: 0,
          requiredCheckpoints: const [],
          resolvedCheckpoints: const [],
          endWalletBalance: 500,
          growthPointsEarned: 0,
          status: GamePeriodStatus.completed,
          createdAt: DateTime.utc(2026),
          completedAt: DateTime.utc(2026),
        );
      });
      final content = TestContentRepository(
        List<PeriodDefinition>.generate(
          5,
          (index) => PeriodDefinition(
            id: 'period_${index + 1}',
            number: index + 1,
            title: 'День ${index + 1}',
            baseIncome: 500,
            requiredCheckpoints: const [],
          ),
        ),
      );
      final games = _AtmosphereGames(database, pet, gameState, null)
        ..periodsOverride = periods;
      final container = ProviderContainer(
        overrides: [
          campaignLifecycleServiceProvider.overrideWithValue(
            CampaignOnlyLifecycleService(),
          ),
          storyEventServiceProvider.overrideWithValue(
            _NoopStoryEventService(SqliteStoryEventPort(database), content),
          ),
          appDatabaseProvider.overrideWithValue(database),
          activeProfileIdProvider.overrideWith(() => _ActiveProfileMock(1)),
          profileRepositoryProvider.overrideWithValue(
            _AtmosphereProfiles(profile),
          ),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final ready = container.read(homeControllerProvider) as HomeReady;
      expect(ready.completedDays, 5);
      expect(ready.allDaysCompleted, isTrue);
      expect(find.byKey(const Key('home-day-status')), findsOneWidget);
      expect(find.text('Все 5 дней завершены'), findsOneWidget);
      expect(find.text('Можно начать день 6.'), findsNothing);
      final renderedText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .join('\n')
          .toLowerCase();
      expect(renderedText, isNot(contains('день 6')));
    });
  });

  group('HomeScreen atmosphere and interactions', () {
    Future<({ProviderContainer container, _AtmosphereGames games})>
    controllerHarness() async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final profile = Profile(
        id: 1,
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      );
      const pet = Pet(
        profileId: 1,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 40,
        care: 40,
        mood: 40,
      );
      final gameState = GameState(
        profileId: 1,
        walletBalance: 500,
        currentPeriod: 1,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026),
      );
      final period = GamePeriod(
        id: 10,
        profileId: 1,
        definitionId: 'period_1',
        periodNumber: 1,
        startWalletBalance: 500,
        baseIncome: 500,
        extraIncome: 0,
        plannedNeed: 0,
        plannedWant: 0,
        plannedSavings: 0,
        plannedFree: 500,
        actualNeed: 0,
        actualWant: 0,
        actualSavings: 0,
        requiredCheckpoints: const [],
        resolvedCheckpoints: const [],
        growthPointsEarned: 0,
        status: GamePeriodStatus.active,
        createdAt: DateTime.utc(2026),
      );
      final games = _AtmosphereGames(database, pet, gameState, period);
      final container = ProviderContainer(
        overrides: [
          campaignLifecycleServiceProvider.overrideWithValue(
            CampaignOnlyLifecycleService(),
          ),
          appDatabaseProvider.overrideWithValue(database),
          activeProfileIdProvider.overrideWith(() => _ActiveProfileMock(1)),
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
      return (container: container, games: games);
    }

    for (final interaction in FreePetInteraction.values) {
      test(
        'usage read error for ${interaction.name} produces HomeFailure',
        () async {
          final harness = await controllerHarness();
          harness.games.failingUsageActionId = interaction.actionId;
          final states = <HomeViewState>[];
          harness.container.listen(
            homeControllerProvider,
            (_, next) => states.add(next),
          );

          await harness.container.read(homeControllerProvider.notifier).load();

          expect(
            harness.container.read(homeControllerProvider),
            isA<HomeFailure>(),
          );
          expect(states.whereType<HomeReady>(), isEmpty);
          expect(harness.games.petUsage, 0);
        },
      );
    }

    test('usage reads slower than 100 ms preserve persisted counts', () async {
      final harness = await controllerHarness();
      harness.games
        ..usageReadDelay = const Duration(milliseconds: 200)
        ..petUsage = 1;

      await harness.container.read(homeControllerProvider.notifier).load();

      final ready = harness.container.read(homeControllerProvider) as HomeReady;
      expect(ready.petUsageCount, 1);
    });

    test('confirmed usage remains used after Home reload', () async {
      final harness = await controllerHarness();
      harness.games.petUsage = 1;
      final controller = harness.container.read(
        homeControllerProvider.notifier,
      );

      await controller.load();
      var ready = harness.container.read(homeControllerProvider) as HomeReady;
      expect(ready.petUsageCount, 1);

      await controller.load();
      ready = harness.container.read(homeControllerProvider) as HomeReady;
      expect(ready.petUsageCount, 1);
    });

    testWidgets('elapsed foreground time and pause resume do not mutate Pet', (
      tester,
    ) async {
      final harness = await controllerHarness();
      final beforePet = harness.games.pet.toMap();
      final beforePeriod = harness.games.period!.toMap();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(harness.games.pet.toMap(), beforePet);
      expect(harness.games.period?.toMap(), beforePeriod);
    });

    testWidgets(
      'renders Pet, wallet, stat indicators, day status, today card and goal',
      (tester) async {
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
            campaignLifecycleServiceProvider.overrideWithValue(
              CampaignOnlyLifecycleService(),
            ),
            appDatabaseProvider.overrideWithValue(database),
            activeProfileIdProvider.overrideWith(() => _ActiveProfileMock(1)),
            profileRepositoryProvider.overrideWithValue(profiles),
            gameRepositoryProvider.overrideWithValue(games),
            contentRepositoryProvider.overrideWithValue(content),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
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

        // The canonical free interaction remains; legacy one-tap play is gone.
        expect(find.byKey(const Key('home-free-pet')), findsOneWidget);
        expect(find.byKey(const Key('home-free-play')), findsNothing);
        expect(find.text('Погладить'), findsOneWidget);
        expect(find.text('Поиграть'), findsNothing);
        expect(find.byKey(const Key('home-day-sky')), findsOneWidget);
        expect(find.byKey(const Key('home-sun')), findsOneWidget);
        expect(find.text('Утро'), findsNothing);
        expect(find.text('День'), findsNothing);
        expect(find.text('Вечер'), findsNothing);

        // Day status card and the next unresolved action.
        expect(find.byKey(const Key('home-day-status')), findsOneWidget);
        expect(find.byKey(const Key('home-next-savings')), findsOneWidget);
        expect(find.text('Решить про накопления'), findsOneWidget);

        // Today card with checkpoints
        expect(find.byKey(const Key('home-today-card')), findsOneWidget);
        expect(find.text('Сегодня'), findsOneWidget);
        expect(find.text('Задание дня'), findsOneWidget);
        expect(find.text('Накопления'), findsOneWidget);
        expect(find.text('Готово'), findsOneWidget);
        expect(find.text('Событие'), findsNothing);
        expect(find.text('Скидка'), findsNothing);

        // Active savings goal card
        expect(find.byKey(const Key('home-savings-goal')), findsOneWidget);
        expect(find.text('Велосипед'), findsOneWidget);
        expect(find.text('150/500 🪙'), findsOneWidget);

        final morningSun = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(const Key('home-sun')),
            matching: find.byType(Positioned),
          ),
        );
        final morningSky = tester.widget<Container>(
          find.byKey(const Key('home-day-sky')),
        );
        final morningGradient =
            (morningSky.decoration! as BoxDecoration).gradient!
                as LinearGradient;

        games.period = period.copyWith(dayProgress: 100);
        await container.read(homeControllerProvider.notifier).load();
        await tester.pumpAndSettle();
        final eveningSun = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(const Key('home-sun')),
            matching: find.byType(Positioned),
          ),
        );
        final eveningSky = tester.widget<Container>(
          find.byKey(const Key('home-day-sky')),
        );
        final eveningGradient =
            (eveningSky.decoration! as BoxDecoration).gradient!
                as LinearGradient;
        expect(eveningSun.left, greaterThan(morningSun.left!));
        expect(eveningGradient.colors, isNot(morningGradient.colors));
        expect(find.byKey(const Key('home-finish-day')), findsOneWidget);

        games.period = period.copyWith(
          status: GamePeriodStatus.readyToFinish,
          dayProgress: 60,
          resolvedCheckpoints: const ['financial_task', 'savings_decision'],
        );
        await container.read(homeControllerProvider.notifier).load();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('home-finish-day')), findsNothing);
        expect(find.byKey(const Key('home-view-plan')), findsOneWidget);
      },
    );

    testWidgets(
      'free interaction changes button state to used today and disabled',
      (tester) async {
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
            campaignLifecycleServiceProvider.overrideWithValue(
              CampaignOnlyLifecycleService(),
            ),
            appDatabaseProvider.overrideWithValue(database),
            activeProfileIdProvider.overrideWith(() => _ActiveProfileMock(1)),
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
            child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Pet button should show checkmark and be disabled
        final petBtnFinder = find.byKey(const Key('home-free-pet'));
        expect(petBtnFinder, findsOneWidget);
        expect(find.text('Погладить ✓'), findsOneWidget);
        final buttonWidget = tester.widget<FilledButton>(petBtnFinder);
        expect(buttonWidget.onPressed, isNull);

        expect(find.byKey(const Key('home-free-play')), findsNothing);
      },
    );
  });
}

class _ActiveProfileMock extends ActiveProfileIdController {
  _ActiveProfileMock(this.id);
  final int id;
  @override
  int? build() => id;
}
