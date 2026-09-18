import 'package:finny/app/app.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/app/router.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

class _NavProfiles implements ProfileRepository {
  _NavProfiles(this.profile);
  final Profile profile;

  @override
  Future<Profile> create(Profile profile) async => profile;

  @override
  Future<List<Profile>> findAll() async => [profile];

  @override
  Future<Profile?> findById(int id) async => id == profile.id ? profile : null;

  @override
  Future<void> update(Profile profile) async {}
}

class _NavGames extends SqliteGameRepository {
  _NavGames(super.database, this.pet, this.gameState);

  final Pet pet;
  final GameState gameState;

  @override
  Future<GameState> ensureInitialState(int profileId) async => gameState;

  @override
  Future<GameState?> getGameState(int profileId) async => gameState;

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async => const [];

  @override
  Future<GamePeriod?> getCurrentPeriod(int profileId) async => null;

  @override
  Future<Pet?> getPet(int profileId) async => pet;

  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async => 0;

}

void main() {
  testWidgets(
    '5 bottom navigation tabs in exact order, tap transitions and outside-shell route isolation',
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
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 100,
        care: 100,
        mood: 100,
      );
      final gameState = GameState(
        profileId: 1,
        walletBalance: 500,
        currentPeriod: 0,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final profiles = _NavProfiles(profile);
      final games = _NavGames(database, pet, gameState);

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profiles),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(
            TestContentRepository(testPeriodDefinitions()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FinnyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Bootstrap navigates existing profile with pet to /home
      expect(find.byType(NavigationBar), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations, hasLength(5));

      // Verify exact destination labels and icons in order
      expect((navBar.destinations[0] as NavigationDestination).label, 'Финни');
      expect((navBar.destinations[1] as NavigationDestination).label, 'Вещи');
      expect((navBar.destinations[2] as NavigationDestination).label, 'Магазин');
      expect((navBar.destinations[3] as NavigationDestination).label, 'Задания');
      expect((navBar.destinations[4] as NavigationDestination).label, 'Накопления');
      expect(navBar.selectedIndex, 0);

      Finder navItem(String label) => find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          );

      // Tap "Вещи" (index 1)
      await tester.tap(navItem('Вещи'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      // Tap "Магазин" (index 2)
      await tester.tap(navItem('Магазин'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );

      // Tap "Задания" (index 3)
      await tester.tap(navItem('Задания'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );

      // Tap "Накопления" (index 4)
      await tester.tap(navItem('Накопления'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );

      // Tap back to "Финни" (index 0)
      await tester.tap(navItem('Финни'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );

      // Navigate to outside-shell route: /budget
      container.read(routerProvider).go('/budget');
      await tester.pumpAndSettle();
      // NavigationBar must NOT be present on /budget
      expect(find.byType(NavigationBar), findsNothing);
    },
  );
}