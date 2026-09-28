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
                ShopEquipSlot.back: 'accessory_hat',
              },
            ),
          ),
        ),
      );
      final canvas = tester.getRect(find.byKey(const Key('home-finny-canvas')));
      for (final (id, asset) in [
        ('accessory_bow', 'assets/images/things/cap_wearable.png'),
        ('accessory_collar', 'assets/images/things/bandana_wearable.png'),
        ('accessory_hat', 'assets/images/things/wings.png'),
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

  testWidgets('all accessory slot combinations remain independent', (
    tester,
  ) async {
    const entries = [
      (ShopEquipSlot.head, 'accessory_bow'),
      (ShopEquipSlot.neck, 'accessory_collar'),
      (ShopEquipSlot.back, 'accessory_hat'),
    ];
    for (var mask = 0; mask < 8; mask++) {
      final equipped = {
        for (var i = 0; i < entries.length; i++)
          if (mask & (1 << i) != 0) entries[i].$1: entries[i].$2,
      };
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(mask),
          home: Scaffold(
            body: FinnyRoomScene(pet: pet, equippedAccessories: equipped),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      for (var i = 0; i < entries.length; i++) {
        expect(
          find.byKey(Key('home-accessory-${entries[i].$2}')),
          mask & (1 << i) != 0 ? findsOneWidget : findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('all eight canonical room composites at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const expected = [
        'room_base.png',
        'room_night_light.png',
        'room_scooter.png',
        'room_night_light_scooter.png',
        'room_play_house.png',
        'room_night_light_play_house.png',
        'room_scooter_play_house.png',
        'room_all_rewards.png',
      ];
      final visuals = HomeRoomVisual.rewards;
      double? initialWidth;
      for (var mask = 0; mask < 8; mask++) {
        final selected = [
          for (var i = 0; i < 3; i++)
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
        final asset = HomeRoomVisual.roomAssetFor(selected, profileId: 1);
        expect(asset, 'assets/images/home/${expected[mask]}');
        expect(
          HomeRoomVisual.roomAssetFor(selected.reversed.toList(), profileId: 1),
          asset,
        );
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(mask),
            home: Scaffold(
              body: HomeSceneBackdrop(
                roomAsset: asset,
                child: FinnyRoomScene(pet: pet),
              ),
            ),
          ),
        );
        await tester.pump();
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const Key('home-room-background')),
            matching: find.byType(Image),
          ),
        );
        expect((image.image as AssetImage).assetName, asset);
        final width = tester
            .getSize(find.byKey(const Key('home-finny-canvas')))
            .width;
        initialWidth ??= width;
        expect(width, initialWidth);
        expect(tester.takeException(), isNull);
      }
    });
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

  testWidgets('equipment and room composites transition without losing state', (
    tester,
  ) async {
    Widget scene(bool visible, {bool disabled = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Scaffold(
          body: HomeSceneBackdrop(
            roomAsset: visible
                ? 'assets/images/home/room_scooter.png'
                : 'assets/images/home/room_base.png',
            child: FinnyRoomScene(
              pet: pet,
              equippedAccessories: visible
                  ? const {ShopEquipSlot.head: 'accessory_bow'}
                  : const {},
            ),
          ),
        ),
      ),
    );
    final accessory = find.byKey(const Key('home-accessory-accessory_bow'));
    await tester.pumpWidget(scene(false));
    expect(accessory, findsNothing);
    await tester.pumpWidget(scene(true));
    expect(accessory, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(scene(false));
    await tester.pump(const Duration(milliseconds: 350));
    expect(accessory, findsNothing);
    await tester.pumpWidget(scene(true, disabled: true));
    await tester.pumpWidget(scene(false, disabled: true));
    await tester.pump();
    expect(accessory, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
