import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/features/home/home_room_visual.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pet = Pet(
    profileId: 1,
    name: 'Финни',
    colorId: 'blue',
    patternId: 'plain',
    developmentStage: 1,
    growthPoints: 0,
    satiety: 70,
    care: 70,
    mood: 70,
  );

  testWidgets('room uses selected appearance for each canonical stage', (
    tester,
  ) async {
    for (final stage in [1, 2, 3]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinnyRoomScene(pet: pet.copyWith(developmentStage: stage)),
          ),
        ),
      );
      await tester.pump();
      final art = tester.widget<Image>(
        find.byKey(Key('home-finny-stage-$stage')),
      );
      expect(
        (art.image as AssetImage).assetName,
        FinnyVisual.assetForPet(pet.copyWith(developmentStage: stage)),
      );
      expect(find.byKey(const Key('home-room-background')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('360dp room and wallet fit with enlarged Russian text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(child: Text('Свободный день')),
                          HomeWallet(balance: 12345),
                          IconButton(
                            onPressed: null,
                            icon: Icon(Icons.settings_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: FinnyRoomScene(pet: pet),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HomeWallet), findsOneWidget);
    expect(find.byKey(const Key('home-room-scene')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final stage in [1, 2, 3]) {
    testWidgets('wearable assets use stage $stage anchors in the pet canvas', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinnyRoomScene(
              pet: pet.copyWith(developmentStage: stage),
              equippedAccessories: const {
                ShopEquipSlot.head: 'accessory_bow',
                ShopEquipSlot.neck: 'accessory_collar',
              },
            ),
          ),
        ),
      );
      final canvas = tester.getRect(find.byKey(const Key('home-finny-canvas')));
      for (final (id, asset) in [
        ('accessory_bow', 'assets/images/things/headphones_wearable.png'),
        ('accessory_collar', 'assets/images/things/glasses_wearable.png'),
      ]) {
        final visual = HomeRoomVisual.accessories.singleWhere(
          (v) => v.itemId == id,
        );
        final finder = find.byKey(Key('home-accessory-$id'));
        expect(
          (tester.widget<Image>(finder).image as AssetImage).assetName,
          asset,
        );
        final expected = visual.anchorFor(stage);
        final actual = tester.getRect(finder);
        expect(
          actual.left,
          closeTo(canvas.left + expected.left * canvas.width, 0.1),
        );
        expect(
          actual.top,
          closeTo(canvas.top + expected.top * canvas.height, 0.1),
        );
        expect(actual.width, closeTo(expected.width * canvas.width, 0.1));
        expect(actual.height, closeTo(expected.height * canvas.height, 0.1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets(
      'all reward subsets have stable independent positions at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final visuals = HomeRoomVisual.rewards;
        for (var mask = 1; mask < 8; mask++) {
          final selected = [
            for (var i = 2; i >= 0; i--)
              if (mask & (1 << i) != 0)
                CompletedGoal(
                  profileId: 1,
                  goalId: visuals[i].goalId,
                  rewardAssetId: visuals[i].rewardAssetId,
                  pricePaid: 1,
                  completedAt: DateTime.utc(2026),
                  claimOperationId: 'claim:$i',
                ),
          ];
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey(mask),
              home: Scaffold(
                body: FinnyRoomScene(pet: pet, completedGoals: selected),
              ),
            ),
          );
          for (var i = 0; i < 3; i++) {
            final finder = find.byKey(
              Key('home-reward-${visuals[i].rewardAssetId}'),
            );
            expect(
              finder,
              mask & (1 << i) != 0 ? findsOneWidget : findsNothing,
            );
            if (mask & (1 << i) != 0) {
              final scene = tester.getRect(
                find.byKey(const Key('home-room-scene')),
              );
              final rect = tester.getRect(finder);
              expect(
                rect.left,
                closeTo(
                  scene.left + visuals[i].placement.left * scene.width,
                  0.1,
                ),
              );
              expect(
                rect.top,
                closeTo(
                  scene.top + visuals[i].placement.top * scene.height,
                  0.1,
                ),
              );
            }
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('idle and pet reaction animate and dispose safely', (
    tester,
  ) async {
    Widget scene(int token, {bool disabled = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Scaffold(
          body: FinnyRoomScene(pet: pet, petReactionToken: token),
        ),
      ),
    );
    await tester.pumpWidget(scene(0));
    final finder = find.byKey(const Key('home-finny-motion'));
    expect(tester.widget<Transform>(finder).transform.storage[13], 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.widget<Transform>(finder).transform.storage[13], lessThan(0));
    await tester.pumpWidget(scene(1));
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.widget<Transform>(finder).transform.storage[13], lessThan(0));
    await tester.pumpWidget(scene(2, disabled: true));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<Transform>(finder).transform.storage[13], 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new equipment and rewards fade in and out only on changes', (
    tester,
  ) async {
    final completed = CompletedGoal(
      profileId: 1,
      goalId: 'goal_scooter',
      rewardAssetId: 'reward_scooter',
      pricePaid: 1,
      completedAt: DateTime.utc(2026),
      claimOperationId: 'claim:scooter',
    );
    Widget scene(bool visible, {bool disabled = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Scaffold(
          body: FinnyRoomScene(
            pet: pet,
            equippedAccessories: visible
                ? const {ShopEquipSlot.head: 'accessory_bow'}
                : const {},
            completedGoals: visible ? [completed] : const [],
          ),
        ),
      ),
    );
    final accessory = find.byKey(const Key('home-accessory-accessory_bow'));
    final reward = find.byKey(const Key('home-reward-reward_scooter'));
    await tester.pumpWidget(scene(false));
    expect(accessory, findsNothing);
    expect(reward, findsNothing);
    await tester.pumpWidget(scene(true));
    expect(accessory, findsOneWidget);
    expect(reward, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(scene(false));
    expect(accessory, findsOneWidget);
    expect(reward, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(accessory, findsNothing);
    expect(reward, findsNothing);
    await tester.pumpWidget(scene(true, disabled: true));
    await tester.pumpWidget(scene(false, disabled: true));
    await tester.pump();
    expect(accessory, findsNothing);
    expect(reward, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
