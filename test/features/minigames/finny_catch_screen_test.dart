import 'package:finny/app/providers.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_art.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_controller.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_screen.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_database.dart';

class _CatchProfile extends ActiveProfileIdController {
  @override
  int? build() => 1;
}

class _CatchGames extends SqliteGameRepository {
  _CatchGames(super.database);

  @override
  Future<Pet?> getPet(int profileId) async => const Pet(
    profileId: 1,
    name: 'Пикси',
    colorId: 'blue',
    patternId: 'spots',
    developmentStage: 3,
    growthPoints: 100,
    satiety: 70,
    care: 70,
    mood: 70,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime clock;
  late FinnyCatchController controller;
  late GoRouter router;
  var runNumber = 0;
  var rewardCount = 0;

  setUp(() {
    clock = DateTime.utc(2026, 9, 24);
    runNumber = 0;
    rewardCount = 0;
    controller = FinnyCatchController(
      profileId: 1,
      grantReward:
          ({required profileId, required amount, required runId}) async {
            rewardCount++;
            return GameState(
              profileId: profileId,
              walletBalance: amount,
              currentPeriod: 5,
              savedAmount: 0,
              updatedAt: clock,
            );
          },
      now: () => clock,
      runIdFactory: () => 'widget-run-${runNumber++}',
      seedFactory: () => 42,
      autoTick: false,
    );
    router = GoRouter(
      initialLocation: '/finny-catch',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/finny-catch',
          builder: (_, _) => FinnyCatchScreen(controller: controller),
        ),
      ],
    );
  });
  tearDown(() {
    router.dispose();
    controller.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(360, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();
  }

  Future<void> elapse(WidgetTester tester, Duration duration) async {
    clock = clock.add(duration);
    controller.tick();
    await tester.pump();
  }

  void expectMountainBackground(WidgetTester tester, Size screenSize) {
    final background = find.byKey(const Key('finny-catch-background'));
    expect(background, findsOneWidget);
    final image = tester.widget<Image>(background);
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/minigames/finny_catch/background_mountains.png',
    );
    expect(image.fit, BoxFit.cover);
    expect(tester.getSize(background), screenSize);
  }

  void expectRoundedGameButton(WidgetTester tester, String label) {
    final button = find.ancestor(
      of: find.text(label),
      matching: find.byKey(const Key('finny-catch-game-button')),
    );
    expect(button, findsOneWidget);

    final material = tester.widget<Material>(button);
    expect(
      material.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(40)),
      ),
    );
    expect(material.clipBehavior, Clip.antiAlias);

    final shadow = find.ancestor(
      of: button,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            ((widget.decoration as BoxDecoration).boxShadow?.any(
                  (boxShadow) => boxShadow.color == const Color(0x335C3CD6),
                ) ??
                false),
      ),
    );
    expect(shadow, findsOneWidget);
    final shadowDecoration = tester.widget<DecoratedBox>(shadow).decoration;
    expect(
      (shadowDecoration as BoxDecoration).borderRadius,
      const BorderRadius.all(Radius.circular(40)),
    );
  }

  testWidgets('free play uses the active Pet appearance with fixed hitbox', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeProfileIdProvider.overrideWith(_CatchProfile.new),
          gameRepositoryProvider.overrideWithValue(_CatchGames(database)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    final art = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/finny/stage3/blue_spots.png',
    );
    expect(art, findsOneWidget);
    expect(controller.finnyVisualWidth, greaterThan(0));
    expect(tester.getSize(art).width, controller.finnyVisualWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'prepare reference content fits 360dp and has no falling objects or nav',
    (tester) async {
      await mount(tester);
      expectMountainBackground(tester, const Size(360, 800));
      expect(find.text('Лови монеты'), findsOneWidget);
      expect(find.text('Очки'), findsOneWidget);
      expect(find.text('30 сек'), findsOneWidget);
      expect(find.text('Приготовься!'), findsOneWidget);
      expect(
        find.text('Двигай Финни пальцем\nи лови полезные предметы'),
        findsOneWidget,
      );
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('Избегай'), findsOneWidget);
      expect(find.text('Начать игру'), findsOneWidget);
      final header = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xCCF9F8FF),
      );
      expect(header, findsOneWidget);
      final headerDecoration = tester.widget<Container>(header).decoration;
      expect(
        (headerDecoration as BoxDecoration).borderRadius,
        const BorderRadius.all(Radius.circular(34)),
      );
      expectRoundedGameButton(tester, 'Начать игру');
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(controller.state.objects, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('prepare and result fit 393x852 without overflow', (
    tester,
  ) async {
    await mount(tester, size: const Size(393, 852));
    expectMountainBackground(tester, const Size(393, 852));
    expect(find.text('Начать игру'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Начать игру'));
    await tester.pump();
    await elapse(tester, const Duration(seconds: 2));
    await elapse(tester, const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('Отличная игра!'), findsOneWidget);
    expectMountainBackground(tester, const Size(393, 852));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'primary buttons keep one rounded shape in prepare, pause and result',
    (tester) async {
      await mount(tester);
      expectRoundedGameButton(tester, 'Начать игру');

      await tester.tap(find.text('Начать игру'));
      await tester.pump();
      await elapse(tester, const Duration(seconds: 2));
      controller.pause();
      await tester.pump();
      expect(controller.state.phase, FinnyCatchPhase.paused);
      expect(find.text('Продолжить'), findsOneWidget);
      expectRoundedGameButton(tester, 'Продолжить');

      await tester.tap(find.text('Продолжить'));
      await tester.pump();
      await elapse(tester, const Duration(seconds: 30));
      await tester.pump();
      expect(find.text('Сыграть ещё'), findsOneWidget);
      expectRoundedGameButton(tester, 'Сыграть ещё');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mountain background is bundled and loads without errors', (
    tester,
  ) async {
    await mount(tester);
    final data = await rootBundle.load(
      'assets/minigames/finny_catch/background_mountains.png',
    );
    expect(data.lengthInBytes, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone sparkle loads at HUD, legend and field sizes', (
    tester,
  ) async {
    const sizes = [38.0, 58.0, 64.8, 70.74];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final size in sizes)
                FinnyCatchArt(type: FinnyCatchObjectType.sparkle, size: size),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final images = tester.widgetList<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == FinnyCatchAssets.sparkle,
      ),
    );
    expect(images.length, sizes.length);
    for (final (index, image) in images.indexed) {
      expect(image.width, sizes[index]);
      expect(image.height, sizes[index]);
      expect(image.fit, BoxFit.contain);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'countdown holds HUD then gameplay accepts direct drag within bounds',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Начать игру'));
      await tester.pump();
      expectMountainBackground(tester, const Size(360, 800));
      expect(find.text('3'), findsOneWidget);
      await elapse(tester, const Duration(milliseconds: 1500));
      expect(find.text('Старт!'), findsOneWidget);
      expect(find.text('30 сек'), findsOneWidget);
      expect(controller.state.objects, isEmpty);
      await elapse(tester, const Duration(milliseconds: 500));
      expect(controller.state.phase, FinnyCatchPhase.playing);
      await elapse(tester, const Duration(seconds: 1));
      expect(find.text('29 сек'), findsOneWidget);
      expectMountainBackground(tester, const Size(360, 800));
      final before = controller.state.finnyX;
      await tester.dragFrom(const Offset(180, 500), const Offset(170, 0));
      await tester.pump();
      expect(controller.state.finnyX, greaterThan(before));
      expect(controller.state.finnyX, lessThan(1));
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'result freezes HUD, shows reward and replay resets on same route',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Начать игру'));
      await tester.pump();
      await elapse(tester, const Duration(seconds: 2));
      await elapse(tester, const Duration(seconds: 30));
      await tester.pump();
      expect(find.text('0 сек'), findsOneWidget);
      expect(find.text('Отличная игра!'), findsOneWidget);
      expectMountainBackground(tester, const Size(360, 800));
      expect(find.text('Награда'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(rewardCount, 1);
      expect(find.text('Сыграть ещё'), findsOneWidget);
      expect(find.text('Вернуться к Финни'), findsOneWidget);
      await tester.tap(find.text('Сыграть ещё'));
      await tester.pump();
      expect(controller.state.runId, 'widget-run-1');
      expect(controller.state.phase, FinnyCatchPhase.prepare);
      expect(controller.state.score, 0);
      expect(find.text('30 сек'), findsOneWidget);
      expect(find.text('Начать игру'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back leaves prepare; active back pauses and requires confirmation',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(rewardCount, 0);
    },
  );

  testWidgets('result return uses Home fallback when opened directly', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Начать игру'));
    await tester.pump();
    await elapse(tester, const Duration(seconds: 2));
    await elapse(tester, const Duration(seconds: 30));
    await tester.pump();
    expect(rewardCount, 1);
    await tester.tap(find.text('Вернуться к Финни'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('active back shows pause confirmation without granting reward', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Начать игру'));
    await tester.pump();
    await elapse(tester, const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(controller.state.phase, FinnyCatchPhase.paused);
    expect(find.text('Выйти из игры?'), findsOneWidget);
    expectMountainBackground(tester, const Size(360, 800));
    expect(find.text('Награда за этот раунд не сохранится.'), findsOneWidget);
    expect(rewardCount, 0);
    await tester.tap(find.text('Продолжить').last);
    await tester.pumpAndSettle();
    expect(controller.state.phase, FinnyCatchPhase.playing);
  });

  testWidgets(
    'background pauses and does not silently finish or grant reward',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Начать игру'));
      await tester.pump();
      await elapse(tester, const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      clock = clock.add(const Duration(seconds: 40));
      controller.tick();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.state.phase, FinnyCatchPhase.paused);
      expect(find.text('Пауза'), findsOneWidget);
      expect(controller.state.remainingSeconds, 30);
      expect(rewardCount, 0);
    },
  );
}
