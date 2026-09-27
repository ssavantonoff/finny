import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/home/home_visual_components.dart';
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
}
