import 'package:finny/app/app.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/app/router.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/services/free_play_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

class _DisplayGames extends SqliteGameRepository {
  _DisplayGames(super.database, this.periods, this.state, this.pet);
  final List<GamePeriod> periods;
  final GameState state;
  final Pet pet;
  @override
  Future<GameState> ensureInitialState(int profileId) async => state;
  @override
  Future<GameState?> getGameState(int profileId) async => state;
  @override
  Future<Pet?> getPet(int profileId) async => pet;
  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async => periods;
  @override
  Future<GamePeriod?> getCurrentPeriod(int profileId) async => null;
  @override
  Future<List<CompletedGoal>> getCompletedGoals(int profileId) async =>
      const [];
  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async => 0;
}

class _DisplayFreePlayService extends FreePlayService {
  _DisplayFreePlayService(super.repository, super.content, super.games);
  @override
  Future<Map<ShopEquipSlot, String>> equipped(int profileId) async => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
      await tester.pump();
    }
    expect(finder, findsOneWidget);
  }

  Future<(AppDatabase, TestContentRepository, _DisplayGames)> completedSave(
    WidgetTester tester, {
    bool clearActiveGoal = false,
    int savedAmount = 0,
  }) async => (await tester.runAsync(() async {
    final database = createTestDatabase();
    final db = await database.database;
    const profileId = 1;
    await db.insert('profiles', {
      'id': profileId,
      'game_name': 'Игрок',
      'profile_type': 'NORMAL',
      'onboarding_completed': 1,
      'created_at': DateTime.utc(2026).toIso8601String(),
    });
    final games = SqliteGameRepository(database);
    await games.ensureInitialState(profileId);
    await games.savePet(
      const Pet(
        profileId: profileId,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 3,
        growthPoints: 300,
        satiety: 80,
        care: 80,
        mood: 80,
      ),
    );
    final assets = AssetContentRepository();
    final definitions = await assets.loadPeriods();
    for (final day in definitions) {
      await db.insert('game_periods', {
        'profile_id': profileId,
        'definition_id': day.id,
        'period_number': day.number,
        'start_wallet_balance': 100,
        'status': 'completed',
        'created_at': DateTime.utc(2026).toIso8601String(),
        'completed_at': DateTime.utc(2026).toIso8601String(),
      });
    }
    return (
      database,
      TestContentRepository(
        List<PeriodDefinition>.of(definitions),
        shopItems: await assets.loadShopItems(),
        goals: await assets.loadGoals(),
        tasks: await assets.loadTasks(),
      ),
      _DisplayGames(
        database,
        await games.getPeriods(profileId),
        (await games.getGameState(profileId))!.copyWith(
          clearActiveGoal: clearActiveGoal,
          savedAmount: savedAmount,
        ),
        (await games.getPet(profileId))!,
      ),
    );
  }))!;

  ProviderContainer container(
    AppDatabase database,
    TestContentRepository content,
    _DisplayGames games,
  ) => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      contentRepositoryProvider.overrideWithValue(content),
      gameRepositoryProvider.overrideWithValue(games),
      freePlayServiceProvider.overrideWithValue(
        _DisplayFreePlayService(FreePlayRepository(database), content, games),
      ),
    ],
  );

  testWidgets(
    'old completed save opens finale, finish survives restart and can enter Free Play',
    (tester) async {
      final (database, content, games) = await completedSave(tester);
      addTearDown(database.close);
      var scope = container(database, content, games);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const FinnyApp()),
      );
      await waitFor(tester, find.text('5 дней вместе!'));
      expect(find.text('Продолжить с Финни'), findsOneWidget);
      await tester.runAsync(() async {
        scope.read(routerProvider).go('/shop');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await waitFor(tester, find.text('5 дней вместе!'));
      expect(
        scope.read(routerProvider).routeInformationProvider.value.uri.path,
        '/finale',
      );
      await tapVisible(tester, find.text('Завершить историю'));
      await waitFor(tester, find.text('История завершена'));
      await tester.runAsync(() async {
        scope.read(routerProvider).go('/tasks');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await waitFor(tester, find.text('История завершена'));
      expect(
        scope.read(routerProvider).routeInformationProvider.value.uri.path,
        '/campaign-complete',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      scope = container(database, content, games);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const FinnyApp()),
      );
      await waitFor(tester, find.text('История завершена'));
      await tapVisible(tester, find.text('Посмотреть итоги'));
      await waitFor(tester, find.text('5 дней вместе!'));
      expect(find.text('Продолжить с Финни'), findsNothing);
      await tapVisible(tester, find.text('Назад'));
      await waitFor(tester, find.text('История завершена'));
      await tapVisible(tester, find.text('Продолжить играть'));
      await waitFor(tester, find.text('Свободный день'));
      expect(find.byType(HomeWallet), findsOneWidget);
      expect(find.byType(FinnyRoomScene), findsOneWidget);
      expect(find.byKey(const Key('home-finny-stage-3')), findsOneWidget);
      expect(find.text('🪙'), findsNothing);
      expect(find.text('Начать следующий день'), findsNothing);
      expect(find.text('Уложить Финни спать'), findsNothing);
      expect(find.text('Сегодня'), findsNothing);
      expect(find.text('Погладить'), findsOneWidget);
      await tapVisible(tester, find.text('Посмотреть итоги'));
      await waitFor(tester, find.text('Вернуться к Финни'));
      expect(find.text('Завершить историю'), findsNothing);
      await tapVisible(tester, find.text('Вернуться к Финни'));
      await waitFor(tester, find.text('Свободный день'));
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      scope = container(database, content, games);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const FinnyApp()),
      );
      await waitFor(tester, find.text('Свободный день'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      scope.dispose();
    },
  );

  testWidgets('finale primary enters Free Play and Tasks has completed state', (
    tester,
  ) async {
    final (database, content, games) = await completedSave(tester);
    addTearDown(database.close);
    final scope = container(database, content, games);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const FinnyApp()),
    );
    await waitFor(tester, find.text('5 дней вместе!'));
    await tapVisible(tester, find.text('Продолжить с Финни'));
    await waitFor(tester, find.text('Свободный день'));
    await tester.tap(find.text('Задания').first);
    await waitFor(tester, find.text('Все задания выполнены!'));
    expect(find.text('5 / 5 дней ✓'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-shop')));
    await waitFor(tester, find.byKey(const Key('shop-item-food_treat')));
    expect(find.text('SALE'), findsNothing);
    expect(find.text('Сначала начни игровой период.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    scope.dispose();
  });

  testWidgets('Free Play Home and five destinations fit at 360dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (database, content, games) = await completedSave(
      tester,
      clearActiveGoal: true,
      savedAmount: 73,
    );
    addTearDown(database.close);
    final scope = container(database, content, games);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const FinnyApp()),
    );
    await waitFor(tester, find.text('5 дней вместе!'));
    await tapVisible(tester, find.text('Продолжить с Финни'));
    await waitFor(tester, find.text('Свободный день'));
    expect(find.byType(HomeWallet), findsOneWidget);
    expect(find.byType(FinnyRoomScene), findsOneWidget);
    expect(find.byType(HomeSceneBackdrop), findsOneWidget);
    expect(find.byKey(const Key('home-room-background')), findsOneWidget);
    expect(tester.getBottomRight(find.text('Погладить')).dy, lessThan(730));
    expect(find.text('Накоплено: 73'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(
      tester.getBottomRight(find.byKey(const Key('home-savings-goal'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('nav-home'))).dy),
    );
    final noGoal = tester.widget<Text>(find.text('Цель не выбрана'));
    expect(noGoal.style?.color, AppColors.textPrimary);
    expect(find.byKey(const Key('home-saved-without-goal')), findsOneWidget);
    expect(find.text('Уложить Финни спать'), findsNothing);
    expect(find.text('Начать следующий день'), findsNothing);
    for (final key in [
      'nav-home',
      'nav-things',
      'nav-shop',
      'nav-tasks',
      'nav-savings',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    scope.dispose();
  });
}
