import 'helpers/campaign_only_lifecycle_service.dart';

import 'dart:async';

import 'package:finny/app/app.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

class _Profiles implements ProfileRepository {
  Profile? saved;
  Completer<void>? createGate;
  int creates = 0;
  bool failCreate = false;

  @override
  Future<Profile> create(Profile profile) async {
    creates++;
    await createGate?.future;
    if (failCreate) throw StateError('test create error');
    saved = profile.copyWith(id: 1);
    return saved!;
  }

  @override
  Future<List<Profile>> findAll() async => saved == null ? [] : [saved!];

  @override
  Future<Profile?> findById(int id) async => saved;

  @override
  Future<void> update(Profile profile) async {
    saved = profile;
  }
}

class _Games extends SqliteGameRepository {
  _Games(super.database);

  Pet? pet;
  GameState? gameState;

  @override
  Future<GameState> ensureInitialState(int profileId) async =>
      gameState ??= GameState(
        profileId: profileId,
        walletBalance: 0,
        currentPeriod: 0,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026),
      );

  @override
  Future<GameState?> getGameState(int profileId) async => gameState;

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async => const [];

  @override
  Future<Pet?> getPet(int profileId) async => pet;
}

void main() {
  testWidgets('first launch opens onboarding then Pet Creation', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profiles = _Profiles();
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(_Games(database)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FinnyApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Привет! Я Финни'), findsOneWidget);
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    expect(find.text('Копилка — деньги на будущую цель.'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(profiles.saved, isNull);
    await tester.enterText(find.byType(EditableText), '  Игрок  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Создай своего Финни'), findsOneWidget);
    expect(profiles.saved?.gameName, 'Игрок');
    expect(profiles.saved?.onboardingCompleted, isTrue);
    expect(container.read(activeProfileIdProvider), profiles.saved?.id);
  });

  testWidgets('existing NORMAL with Pet skips onboarding and opens Home', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profiles = _Profiles()
      ..saved = Profile(
        id: 1,
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      );
    final games = _Games(database)
      ..pet = const Pet(
        profileId: 1,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 100,
        care: 100,
        mood: 100,
      );
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(games),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FinnyApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Первый день'), findsOneWidget);
    expect(find.byKey(const Key('home-pet-name')), findsOneWidget);
    expect(find.text('Привет! Я Финни'), findsNothing);
    expect(container.read(activeProfileIdProvider), 1);
  });

  testWidgets('double submit sends one create request', (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profiles = _Profiles()..createGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(_Games(database)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FinnyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Игрок');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    expect(profiles.creates, 1);
    expect(find.text('Сохраняем…'), findsOneWidget);
    profiles.createGate!.complete();
    await tester.pumpAndSettle();
    expect(profiles.creates, 1);
    expect(find.text('Создай своего Финни'), findsOneWidget);
  });

  testWidgets('create error preserves typed name and offers retry', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profiles = _Profiles()..failCreate = true;
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(_Games(database)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FinnyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Игрок');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Игрок'), findsOneWidget);
    expect(
      find.textContaining('Не получилось сохранить игровой профиль'),
      findsOneWidget,
    );
    expect(profiles.saved, isNull);
    expect(container.read(activeProfileIdProvider), isNull);
    profiles.failCreate = false;
    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();
    expect(find.text('Создай своего Финни'), findsOneWidget);
    expect(profiles.saved?.gameName, 'Игрок');
  });
}
