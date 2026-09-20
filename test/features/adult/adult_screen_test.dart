import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/adult/adult_screen.dart';
import 'package:finny/features/settings/settings_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_database.dart';

class _AdultGames extends SqliteGameRepository {
  _AdultGames(
    super.database, {
    this.periods = const [],
    this.pet = _defaultPet,
    required this.gameState,
    this.periodsByProfile = const {},
    this.petsByProfile = const {},
    this.gameStatesByProfile = const {},
    this.periodGates = const {},
    this.failuresRemaining = 0,
  });

  final List<GamePeriod> periods;
  final Pet? pet;
  final GameState? gameState;
  final Map<int, List<GamePeriod>> periodsByProfile;
  final Map<int, Pet?> petsByProfile;
  final Map<int, GameState?> gameStatesByProfile;
  final Map<int, Completer<void>> periodGates;
  int failuresRemaining;
  int readCalls = 0;

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async {
    readCalls++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('read failed');
    }
    await periodGates[profileId]?.future;
    return periodsByProfile[profileId] ?? periods;
  }

  @override
  Future<Pet?> getPet(int profileId) async {
    readCalls++;
    return petsByProfile.containsKey(profileId)
        ? petsByProfile[profileId]
        : pet;
  }

  @override
  Future<GameState?> getGameState(int profileId) async {
    readCalls++;
    return gameStatesByProfile.containsKey(profileId)
        ? gameStatesByProfile[profileId]
        : gameState;
  }
}

const _defaultPet = Pet(
  profileId: 1,
  name: 'Финни',
  colorId: 'blue',
  patternId: 'plain',
  developmentStage: 2,
  growthPoints: 0,
  satiety: 80,
  care: 80,
  mood: 80,
);

final _defaultState = GameState(
  profileId: 1,
  walletBalance: 500,
  currentPeriod: 1,
  savedAmount: 180,
  updatedAt: DateTime.utc(2026, 1, 1),
);

GameState _state(int profileId, int savedAmount) => GameState(
  profileId: profileId,
  walletBalance: 500,
  currentPeriod: 1,
  savedAmount: savedAmount,
  updatedAt: DateTime.utc(2026, 1, 1),
);

GamePeriod _period(int number, GamePeriodStatus status) => GamePeriod(
  id: number,
  profileId: 1,
  definitionId: 'day-$number',
  periodNumber: number,
  startWalletBalance: 0,
  baseIncome: 100,
  extraIncome: 0,
  plannedNeed: 0,
  plannedWant: 0,
  plannedSavings: 0,
  plannedFree: 100,
  actualNeed: 0,
  actualWant: 0,
  actualSavings: 0,
  requiredCheckpoints: const [],
  resolvedCheckpoints: const [],
  growthPointsEarned: 0,
  status: status,
  createdAt: DateTime.utc(2026, 1, number),
  completedAt: status == GamePeriodStatus.completed
      ? DateTime.utc(2026, 1, number)
      : null,
);

class _Harness {
  const _Harness(this.container);

  final ProviderContainer container;
}

Future<_Harness> _pumpAdult(
  WidgetTester tester,
  _AdultGames games, {
  int? profileId = 1,
  String initialLocation = '/adult',
}) async {
  final container = ProviderContainer(
    overrides: [gameRepositoryProvider.overrideWithValue(games)],
  );
  addTearDown(container.dispose);
  if (profileId != null) {
    container
        .read(activeProfileIdProvider.notifier)
        .setActiveProfileId(profileId);
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/adult', builder: (_, _) => const AdultScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container);
}

_AdultGames _games({
  List<GamePeriod> periods = const [],
  Pet? pet = _defaultPet,
  GameState? gameState,
  Map<int, List<GamePeriod>> periodsByProfile = const {},
  Map<int, Pet?> petsByProfile = const {},
  Map<int, GameState?> gameStatesByProfile = const {},
  Map<int, Completer<void>> periodGates = const {},
  int failuresRemaining = 0,
  bool missingGameState = false,
}) {
  final database = createTestDatabase();
  addTearDown(database.close);
  return _AdultGames(
    database,
    periods: periods,
    pet: pet,
    gameState: missingGameState ? null : gameState ?? _defaultState,
    periodsByProfile: periodsByProfile,
    petsByProfile: petsByProfile,
    gameStatesByProfile: gameStatesByProfile,
    periodGates: periodGates,
    failuresRemaining: failuresRemaining,
  );
}

Future<void> _unlock(WidgetTester tester) async {
  await tester.longPress(find.byKey(const Key('adult-unlock')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts behind the adult barrier without reading data', (
    tester,
  ) async {
    final games = _games();
    await _pumpAdult(tester, games);

    expect(find.byKey(const Key('adult-barrier')), findsOneWidget);
    expect(find.byKey(const Key('adult-unlock')), findsOneWidget);
    expect(find.text('О проекте'), findsNothing);
    expect(games.readCalls, 0);
  });

  testWidgets('ordinary tap does not unlock the adult section', (tester) async {
    final games = _games();
    await _pumpAdult(tester, games);

    await tester.tap(find.byKey(const Key('adult-unlock')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adult-barrier')), findsOneWidget);
    expect(find.text('О проекте'), findsNothing);
    expect(games.readCalls, 0);
  });

  testWidgets('long press loads overview and all learning topics', (
    tester,
  ) async {
    final games = _games();
    await _pumpAdult(tester, games);
    await _unlock(tester);

    expect(find.byKey(const Key('adult-barrier')), findsNothing);
    expect(find.text('О проекте'), findsOneWidget);
    expect(find.text('Чему учится ребёнок'), findsOneWidget);
    for (final topic in const [
      'отличать нужное от желаемого',
      'планировать ограниченный бюджет',
      'выбирать приоритеты',
      'откладывать на цель',
      'менять план при неожиданной трате',
      'оценивать скидку без импульсивной покупки',
    ]) {
      expect(find.text(topic), findsOneWidget);
    }
    expect(find.text('Пройдено дней: 0 из 5'), findsOneWidget);
    expect(games.readCalls, 3);
  });

  testWidgets('leaving and reopening Adult restores the barrier', (
    tester,
  ) async {
    final games = _games();
    await _pumpAdult(tester, games, initialLocation: '/settings');

    await tester.tap(find.byKey(const Key('settings-adult')));
    await tester.pumpAndSettle();
    await _unlock(tester);
    expect(find.text('О проекте'), findsOneWidget);

    await tester.tap(find.byKey(const Key('adult-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-adult')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adult-barrier')), findsOneWidget);
    expect(find.text('О проекте'), findsNothing);
  });

  testWidgets('counts only completed periods', (tester) async {
    final games = _games(
      periods: [
        _period(1, GamePeriodStatus.completed),
        _period(2, GamePeriodStatus.completed),
        _period(3, GamePeriodStatus.active),
      ],
    );
    await _pumpAdult(tester, games);
    await _unlock(tester);

    expect(find.text('Пройдено дней: 2 из 5'), findsOneWidget);
  });

  testWidgets('shows five completed days as full progress', (tester) async {
    final games = _games(
      periods: [
        for (var day = 1; day <= 5; day++)
          _period(day, GamePeriodStatus.completed),
      ],
    );
    await _pumpAdult(tester, games);
    await _unlock(tester);

    expect(find.text('Пройдено дней: 5 из 5'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('adult-campaign-progress')),
    );
    expect(indicator.value, 1);
  });

  testWidgets('shows persisted development stage and saved amount', (
    tester,
  ) async {
    final games = _games();
    await _pumpAdult(tester, games);
    await _unlock(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('adult-development')),
      250,
    );
    expect(find.text('Этап развития Финни: 2 из 3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('adult-savings')),
      250,
    );
    expect(find.text('В копилке: 180 монет'), findsOneWidget);
  });

  testWidgets('missing Pet is a valid loaded state', (tester) async {
    final games = _games(pet: null);
    await _pumpAdult(tester, games);
    await _unlock(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('adult-development')),
      250,
    );
    expect(find.text('Финни ещё не создан.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no active profile does not read repository data', (
    tester,
  ) async {
    final games = _games();
    await _pumpAdult(tester, games, profileId: null);
    await _unlock(tester);

    expect(find.text('Профиль пока не выбран.'), findsOneWidget);
    expect(games.readCalls, 0);
  });

  testWidgets('read exception shows the retryable failure state', (
    tester,
  ) async {
    final games = _games(failuresRemaining: 1);
    await _pumpAdult(tester, games);
    await _unlock(tester);

    expect(find.text('Не получилось загрузить прогресс.'), findsOneWidget);
    expect(find.byKey(const Key('adult-retry')), findsOneWidget);
  });

  testWidgets('retry performs a fresh read and reaches loaded content', (
    tester,
  ) async {
    final games = _games(failuresRemaining: 1);
    await _pumpAdult(tester, games);
    await _unlock(tester);

    await tester.tap(find.byKey(const Key('adult-retry')));
    await tester.pumpAndSettle();

    expect(find.text('О проекте'), findsOneWidget);
    expect(find.text('Пройдено дней: 0 из 5'), findsOneWidget);
    expect(games.readCalls, 4);
  });

  testWidgets(
    'missing GameState is a load failure without bootstrap mutation',
    (tester) async {
      final games = _games(missingGameState: true);
      await _pumpAdult(tester, games);
      await _unlock(tester);

      expect(find.text('Не получилось загрузить прогресс.'), findsOneWidget);
      expect(find.byKey(const Key('adult-retry')), findsOneWidget);
    },
  );

  testWidgets('stale profile result cannot replace the current overview', (
    tester,
  ) async {
    final firstProfileGate = Completer<void>();
    final games = _games(
      periodGates: {1: firstProfileGate},
      periodsByProfile: const {1: [], 2: []},
      petsByProfile: const {1: _defaultPet, 2: _defaultPet},
      gameStatesByProfile: {1: _state(1, 111), 2: _state(2, 222)},
    );
    final harness = await _pumpAdult(tester, games);

    await tester.longPress(find.byKey(const Key('adult-unlock')));
    await tester.pump();
    harness.container
        .read(activeProfileIdProvider.notifier)
        .setActiveProfileId(2);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('adult-savings')),
      250,
    );
    expect(find.text('В копилке: 222 монет'), findsOneWidget);

    firstProfileGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('В копилке: 222 монет'), findsOneWidget);
    expect(find.text('В копилке: 111 монет'), findsNothing);
  });

  testWidgets('loaded content is scrollable without overflow at 360x800', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final games = _games();
    await _pumpAdult(tester, games);
    await _unlock(tester);

    expect(find.byType(ListView), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('adult-savings')),
      300,
    );
    expect(tester.takeException(), isNull);
  });
}
