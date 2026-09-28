import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/home/home_room_visual.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

class RoomHarness {
  RoomHarness(this.database, this.games, this.content) {
    restart();
  }

  final AppDatabase database;
  final SqliteGameRepository games;
  final AssetContentRepository content;
  late ProviderContainer container;

  HomeController get home => container.read(homeControllerProvider.notifier);
  HomeReady get ready => container.read(homeControllerProvider) as HomeReady;

  void restart() {
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
      ],
    );
    container.read(activeProfileIdProvider.notifier).setActiveProfileId(1);
  }

  static Future<RoomHarness> create({
    bool freePlay = true,
    SqliteGameRepository Function(AppDatabase)? gamesFactory,
  }) async {
    final database = createTestDatabase();
    final harness = RoomHarness(
      database,
      gamesFactory?.call(database) ?? SqliteGameRepository(database),
      AssetContentRepository(),
    );
    await harness.addProfile(1, freePlay: freePlay);
    await harness.home.load();
    return harness;
  }

  Future<void> addProfile(int id, {bool freePlay = true}) async {
    final db = await database.database;
    await db.insert('profiles', {
      'id': id,
      'game_name': 'Игрок $id',
      'profile_type': 'NORMAL',
      'onboarding_completed': 1,
      'created_at': DateTime.utc(2026).toIso8601String(),
    });
    await games.ensureInitialState(id);
    await games.savePet(
      Pet(
        profileId: id,
        name: 'Финни',
        colorId: 'purple',
        patternId: 'plain',
        developmentStage: 3,
        growthPoints: 300,
        satiety: 80,
        care: 80,
        mood: 80,
      ),
    );
    await db.update(
      'game_states',
      {'wallet_balance': 5000},
      where: 'profile_id = ?',
      whereArgs: [id],
    );
    if (freePlay) {
      for (final period in await content.loadPeriods()) {
        await db.insert('game_periods', {
          'profile_id': id,
          'definition_id': period.id,
          'period_number': period.number,
          'start_wallet_balance': 100,
          'status': 'completed',
          'created_at': DateTime.utc(2026).toIso8601String(),
          'completed_at': DateTime.utc(2026).toIso8601String(),
        });
      }
      await container.read(campaignLifecycleServiceProvider).startFreePlay(id);
    }
  }

  Future<void> ownAccessories() async {
    final service = container.read(freePlayServiceProvider);
    for (final visual in HomeRoomVisual.accessories) {
      await service.purchase(
        profileId: 1,
        itemId: visual.itemId,
        operationId: 'buy:${visual.itemId}',
      );
    }
    await home.load();
  }

  Future<void> claim(String goalId) async {
    final service = container.read(savingsServiceProvider);
    await service.selectGoal(profileId: 1, goalId: goalId);
    final goal = (await content.loadGoals()).singleWhere((g) => g.id == goalId);
    final db = await database.database;
    await db.update(
      'game_states',
      {'saved_amount': goal.price},
      where: 'profile_id = ?',
      whereArgs: [1],
    );
    await service.claimGoal(
      profileId: 1,
      goalId: goalId,
      operationId: 'claim:$goalId',
    );
    await home.load();
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
  }
}

class _DelayedGoalsRepository extends SqliteGameRepository {
  _DelayedGoalsRepository(super.database);
  Completer<void>? blocked;

  @override
  Future<List<CompletedGoal>> getCompletedGoals(int profileId) async {
    if (profileId == 1 && blocked != null) await blocked!.future;
    return super.getCompletedGoals(profileId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> mount(
    WidgetTester tester,
    RoomHarness harness, {
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.runAsync(harness.home.load);
    await tester.pumpAndSettle();
  }

  Finder accessory(String id) => find.byKey(Key('home-accessory-$id'));
  Finder reward(String id) => find.byKey(Key('home-reward-$id'));

  testWidgets(
    'owned accessories appear only after Things equip and disappear on unequip',
    (tester) async {
      final harness = (await tester.runAsync(RoomHarness.create))!;
      addTearDown(harness.dispose);
      await tester.runAsync(harness.ownAccessories);
      await mount(tester, harness);
      expect(accessory('accessory_bow'), findsNothing);

      final things = harness.container.read(thingsControllerProvider.notifier);
      final item = harness.ready.shopItems.singleWhere(
        (i) => i.id == 'accessory_bow',
      );
      await tester.runAsync(() async {
        await things.load();
        await things.toggleAccessory(item);
        await harness.home.load();
      });
      await tester.pumpAndSettle();
      expect(accessory('accessory_bow'), findsOneWidget);
      expect(
        tester.widget<Image>(accessory('accessory_bow')).image,
        const AssetImage('assets/images/things/headphones.png'),
      );

      await tester.runAsync(() async {
        await things.toggleAccessory(item);
        await harness.home.load();
      });
      await tester.pumpAndSettle();
      expect(accessory('accessory_bow'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'head replacement, glasses coexistence and reload use persisted slots',
    (tester) async {
      final harness = (await tester.runAsync(RoomHarness.create))!;
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.ownAccessories();
        final free = harness.container.read(freePlayServiceProvider);
        await free.equip(profileId: 1, itemId: 'accessory_bow');
        await free.equip(profileId: 1, itemId: 'accessory_collar');
      });
      await mount(tester, harness);
      expect(accessory('accessory_bow'), findsOneWidget);
      expect(accessory('accessory_collar'), findsOneWidget);
      await tester.runAsync(() async {
        await harness.container
            .read(freePlayServiceProvider)
            .equip(profileId: 1, itemId: 'accessory_hat');
        await harness.home.load();
      });
      await tester.pumpAndSettle();
      expect(accessory('accessory_bow'), findsNothing);
      expect(accessory('accessory_hat'), findsOneWidget);
      expect(accessory('accessory_collar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      harness.container.dispose();
      harness.restart();
      await mount(tester, harness);
      expect(harness.ready.equippedAccessories, {
        ShopEquipSlot.head: 'accessory_hat',
        ShopEquipSlot.neck: 'accessory_collar',
      });
      expect(accessory('accessory_hat'), findsOneWidget);
      expect(accessory('accessory_collar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active and reached goals stay absent until successful claim', (
    tester,
  ) async {
    final harness = (await tester.runAsync(RoomHarness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.container
          .read(savingsServiceProvider)
          .selectGoal(profileId: 1, goalId: 'goal_night_light');
      await harness.home.load();
    });
    await mount(tester, harness);
    expect(reward('reward_night_light'), findsNothing);
    await tester.runAsync(() async {
      final db = await harness.database.database;
      await db.update(
        'game_states',
        {'saved_amount': 400},
        where: 'profile_id = ?',
        whereArgs: [1],
      );
      await harness.home.load();
    });
    await tester.pumpAndSettle();
    expect(harness.ready.gameState.savedAmount, 400);
    expect(reward('reward_night_light'), findsNothing);
    await tester.runAsync(() async {
      await harness.container
          .read(savingsServiceProvider)
          .claimGoal(
            profileId: 1,
            goalId: 'goal_night_light',
            operationId: 'claim-light',
          );
      await harness.home.load();
    });
    await tester.pumpAndSettle();
    expect(reward('reward_night_light'), findsOneWidget);
    expect(
      tester.widget<Image>(reward('reward_night_light')).image,
      const AssetImage('assets/images/goals/night_light.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all claimed rewards survive a restarted Home snapshot together',
    (tester) async {
      final harness = (await tester.runAsync(RoomHarness.create))!;
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        for (final visual in HomeRoomVisual.rewards) {
          await harness.claim(visual.goalId);
        }
      });
      harness.container.dispose();
      harness.restart();
      await mount(tester, harness);
      expect(harness.ready.completedGoals, hasLength(3));
      for (final visual in HomeRoomVisual.rewards) {
        expect(reward(visual.rewardAssetId), findsOneWidget);
        expect(
          tester.widget<Image>(reward(visual.rewardAssetId)).image,
          AssetImage(visual.asset),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Home snapshot and copyWith are immutable and profile isolated',
    () async {
      final harness = await RoomHarness.create();
      addTearDown(harness.dispose);
      await harness.ownAccessories();
      await harness.container
          .read(freePlayServiceProvider)
          .equip(profileId: 1, itemId: 'accessory_bow');
      await harness.claim('goal_scooter');
      final original = harness.ready;
      final copied = original.copyWith(interacting: true);
      expect(copied.equippedAccessories, original.equippedAccessories);
      expect(copied.completedGoals, original.completedGoals);
      expect(() => copied.equippedAccessories.clear(), throwsUnsupportedError);
      expect(() => copied.completedGoals.clear(), throwsUnsupportedError);
      expect(() => copied.shopItems.clear(), throwsUnsupportedError);
      expect(() => copied.goals.clear(), throwsUnsupportedError);
      await harness.addProfile(2);
      harness.container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(2);
      expect(
        harness.container.read(homeControllerProvider),
        isA<HomeLoading>(),
      );
      await harness.home.load();
      expect(harness.ready.profile.id, 2);
      expect(harness.ready.equippedAccessories, isEmpty);
      expect(harness.ready.completedGoals, isEmpty);
      harness.container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(1);
      await harness.home.load();
      expect(
        harness.ready.equippedAccessories[ShopEquipSlot.head],
        'accessory_bow',
      );
      expect(
        harness.ready.completedGoals.single.rewardAssetId,
        'reward_scooter',
      );
    },
  );

  testWidgets(
    'Campaign accessories stay unequipped until toggled and persist by slot',
    (tester) async {
      final harness = (await tester.runAsync(
        () => RoomHarness.create(freePlay: false),
      ))!;
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await expectLater(
          harness.container
              .read(freePlayServiceProvider)
              .equip(profileId: 1, itemId: 'accessory_bow'),
          throwsA(isA<PetItemNotOwnedException>()),
        );
        final db = await harness.database.database;
        for (final itemId in [
          'accessory_bow',
          'accessory_hat',
          'accessory_collar',
        ]) {
          await db.insert('inventory', {
            'profile_id': 1,
            'item_id': itemId,
            'quantity': 1,
            'acquired_at': DateTime.utc(2026).toIso8601String(),
          });
        }
      });
      await mount(tester, harness);
      expect(harness.ready.freePlay, isFalse);
      expect(harness.ready.equippedAccessories, isEmpty);
      expect(accessory('accessory_bow'), findsNothing);

      final things = harness.container.read(thingsControllerProvider.notifier);
      final bow = harness.ready.shopItems.singleWhere(
        (item) => item.id == 'accessory_bow',
      );
      final hat = harness.ready.shopItems.singleWhere(
        (item) => item.id == 'accessory_hat',
      );
      final collar = harness.ready.shopItems.singleWhere(
        (item) => item.id == 'accessory_collar',
      );
      await tester.runAsync(() async {
        await things.load();
        expect(things.state.freePlay, isFalse);
        expect(things.state.quantityOf(bow.id), 1);
        await things.toggleAccessory(bow);
        await things.toggleAccessory(collar);
        await things.toggleAccessory(hat);
        await harness.home.load();
      });
      await tester.pumpAndSettle();
      expect(accessory('accessory_bow'), findsNothing);
      expect(accessory('accessory_hat'), findsOneWidget);
      expect(accessory('accessory_collar'), findsOneWidget);
      expect(harness.ready.equippedAccessories, {
        ShopEquipSlot.head: 'accessory_hat',
        ShopEquipSlot.neck: 'accessory_collar',
      });

      await tester.runAsync(() async {
        await things.toggleAccessory(hat);
        await harness.home.load();
      });
      await tester.pumpAndSettle();
      expect(accessory('accessory_hat'), findsNothing);
      expect(accessory('accessory_collar'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        harness.container.dispose();
        harness.restart();
        await harness.home.load();
        expect(harness.ready.equippedAccessories, {
          ShopEquipSlot.neck: 'accessory_collar',
        });
        final db = await harness.database.database;
        final periods = await harness.content.loadPeriods();
        for (final period in periods) {
          await db.insert('game_periods', {
            'profile_id': 1,
            'definition_id': period.id,
            'period_number': period.number,
            'start_wallet_balance': 100,
            'status': 'completed',
            'created_at': DateTime.utc(2026).toIso8601String(),
            'completed_at': DateTime.utc(2026).toIso8601String(),
          });
        }
        final lifecycle = harness.container.read(
          campaignLifecycleServiceProvider,
        );
        await lifecycle.finishStory(1);
        await lifecycle.startFreePlay(1);
        await harness.home.load();
        expect(harness.ready.freePlay, isTrue);
        expect(harness.ready.equippedAccessories, {
          ShopEquipSlot.neck: 'accessory_collar',
        });
        await harness.addProfile(2, freePlay: false);
        harness.container
            .read(activeProfileIdProvider.notifier)
            .setActiveProfileId(2);
        await harness.home.load();
        expect(harness.ready.equippedAccessories, isEmpty);
        harness.container
            .read(activeProfileIdProvider.notifier)
            .setActiveProfileId(1);
        await harness.home.load();
        expect(harness.ready.equippedAccessories, {
          ShopEquipSlot.neck: 'accessory_collar',
        });
        await harness.claim('goal_night_light');
      });
      expect(
        HomeRoomVisual.rewardsFor(harness.ready.completedGoals, profileId: 1),
        hasLength(1),
      );
    },
  );

  testWidgets('unknown IDs and mismatched rewards are safely ignored', (
    tester,
  ) async {
    final harness = (await tester.runAsync(RoomHarness.create))!;
    addTearDown(harness.dispose);
    final pet = harness.ready.pet;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinnyRoomScene(
            pet: pet,
            equippedAccessories: const {
              ShopEquipSlot.head: 'legacy_hat',
              ShopEquipSlot.neck: 'accessory_bow',
            },
            completedGoals: [
              CompletedGoal(
                profileId: 1,
                goalId: 'goal_scooter',
                rewardAssetId: 'legacy_reward',
                pricePaid: 600,
                completedAt: DateTime.utc(2026),
                claimOperationId: 'old',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.key?.toString().contains('home-accessory') ?? false),
      ),
      findsNothing,
    );
    expect(reward('reward_scooter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'a delayed old profile snapshot cannot restore its accessories or rewards',
    () async {
      final harness = await RoomHarness.create(
        gamesFactory: _DelayedGoalsRepository.new,
      );
      addTearDown(harness.dispose);
      await harness.ownAccessories();
      await harness.container
          .read(freePlayServiceProvider)
          .equip(profileId: 1, itemId: 'accessory_bow');
      await harness.claim('goal_night_light');
      await harness.addProfile(2);
      final games = harness.games as _DelayedGoalsRepository;
      games.blocked = Completer<void>();
      final stale = harness.home.load();
      harness.container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(2);
      await harness.home.load();
      games.blocked!.complete();
      await stale;
      expect(harness.ready.profile.id, 2);
      expect(harness.ready.equippedAccessories, isEmpty);
      expect(harness.ready.completedGoals, isEmpty);
    },
  );

  testWidgets(
    'collection names come from the same equipped and claimed snapshot as visuals',
    (tester) async {
      final harness = (await tester.runAsync(RoomHarness.create))!;
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.ownAccessories();
        await harness.container
            .read(freePlayServiceProvider)
            .equip(profileId: 1, itemId: 'accessory_bow');
        await harness.claim('goal_scooter');
      });
      await mount(tester, harness, size: const Size(520, 1000));
      for (
        var i = 0;
        i < 100 && find.textContaining('На Финни:').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.textContaining('На Финни: Наушники'), findsOneWidget);
      expect(find.textContaining('В доме: Самокат для Финни'), findsOneWidget);
      expect(accessory('accessory_bow'), findsOneWidget);
      expect(reward('reward_scooter'), findsOneWidget);
      expect(accessory('accessory_collar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    for (final stage in [1, 2, 3]) {
      for (final head in ['accessory_bow', 'accessory_hat']) {
        testWidgets(
          '$head stage $stage at $size keeps accessories and decor inside scene away from HUD',
          (tester) async {
            final harness = (await tester.runAsync(RoomHarness.create))!;
            addTearDown(harness.dispose);
            await tester.runAsync(() async {
              await harness.ownAccessories();
              await harness.container
                  .read(freePlayServiceProvider)
                  .equip(profileId: 1, itemId: head);
              await harness.container
                  .read(freePlayServiceProvider)
                  .equip(profileId: 1, itemId: 'accessory_collar');
              for (final visual in HomeRoomVisual.rewards) {
                await harness.claim(visual.goalId);
              }
              await harness.games.savePet(
                harness.ready.pet.copyWith(developmentStage: stage),
              );
            });
            await mount(tester, harness, size: size);
            final scene = tester.getRect(
              find.byKey(const Key('home-room-scene')),
            );
            final canvas = tester.getRect(
              find.byKey(const Key('home-finny-canvas')),
            );
            expect(
              scene.top,
              greaterThanOrEqualTo(
                tester.getRect(find.byKey(const Key('home-stats'))).bottom,
              ),
            );
            expect(
              scene.bottom,
              lessThanOrEqualTo(
                tester.getRect(find.byKey(const Key('home-free-pet'))).top,
              ),
            );
            for (final id in [head, 'accessory_collar']) {
              final rect = tester.getRect(accessory(id));
              expect(scene.contains(rect.topLeft), isTrue);
              expect(
                scene.contains(rect.bottomRight - const Offset(0.01, 0.01)),
                isTrue,
              );
            }
            final rects = [
              for (final visual in HomeRoomVisual.rewards)
                tester.getRect(reward(visual.rewardAssetId)),
            ];
            for (final rect in rects) {
              expect(scene.contains(rect.topLeft), isTrue);
              expect(
                scene.contains(rect.bottomRight - const Offset(0.01, 0.01)),
                isTrue,
              );
              expect(rect.overlaps(canvas), isFalse);
              for (final other in rects.where((r) => r != rect)) {
                expect(rect.overlaps(other), isFalse);
              }
            }
            final stack = find
                .ancestor(
                  of: find.byKey(Key('home-finny-stage-$stage')),
                  matching: find.byType(Stack),
                )
                .first;
            final children = tester.widget<Stack>(stack).children;
            if (head == 'accessory_hat') {
              expect(children.first, isA<Positioned>());
              expect(children[1], isA<Image>());
            } else {
              expect(children.first, isA<Image>());
            }
            expect(children.last, isA<Positioned>());
            expect(
              find.byKey(const Key('home-room-background')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
