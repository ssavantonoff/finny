import 'package:finny/app/providers.dart';
import 'package:finny/features/minigames/frisbee/frisbee_screen.dart';
import 'package:finny/features/minigames/frisbee/frisbee_session.dart';
import 'package:finny/models/frisbee_reward.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _access = FrisbeeGameAccess(
  profileId: 1,
  mode: FrisbeeGameMode.campaign,
  periodId: 10,
  canonicalMoodEffect: 40,
);

const _pet = Pet(
  profileId: 1,
  name: 'Финни',
  colorId: 'blue',
  patternId: 'plain',
  developmentStage: 3,
  growthPoints: 0,
  satiety: 70,
  care: 70,
  mood: 40,
);

class _ActiveFrisbeeProfile extends ActiveProfileIdController {
  @override
  int? build() => 1;
}

class _NoActiveProfile extends ActiveProfileIdController {
  @override
  int? build() => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late GoRouter router;
  late Future<FrisbeeGameAccess> Function(int) accessCheck;
  late Future<FrisbeeRewardResult> Function(FrisbeeGameAccess, FrisbeeSession)
  rewardCompletion;
  var rewardAttempts = 0;
  var sessionNumber = 0;
  final submittedIds = <String>[];

  setUp(() {
    rewardAttempts = 0;
    sessionNumber = 0;
    submittedIds.clear();
    accessCheck = (_) async => _access;
    rewardCompletion = (access, session) async {
      rewardAttempts++;
      submittedIds.add(session.sessionId);
      return FrisbeeRewardResult(
        status: rewardAttempts == 1
            ? FrisbeeRewardStatus.applied
            : FrisbeeRewardStatus.alreadyRewarded,
        canonicalMoodEffect: 40,
        actualMoodDelta: rewardAttempts == 1 ? 40 : 0,
        pet: _pet.copyWith(mood: 80),
      );
    };
    container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWith(_ActiveFrisbeeProfile.new),
      ],
    );
    router = GoRouter(
      initialLocation: '/toy-frisbee',
      routes: [
        GoRoute(
          path: '/toy-frisbee',
          builder: (_, _) => FrisbeeScreen(
            checkAccess: (profileId) => accessCheck(profileId),
            completeSession: (access, session) =>
                rewardCompletion(access, session),
            loadPet: (_) async => _pet,
            seedFactory: () => 42,
            sessionIdFactory: () => 'widget-frisbee-${sessionNumber++}',
            onClose: () => router.go('/things'),
          ),
        ),
        GoRoute(
          path: '/things',
          builder: (_, _) => const Scaffold(body: Text('Вещи открыты')),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
    container.dispose();
  });

  Future<void> mount(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 24, bottom: 24)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('frisbee-start')));
    await tester.pump();
  }

  Offset scenePoint(WidgetTester tester, double x, double y) {
    final rect = tester.getRect(find.byKey(const Key('frisbee-gesture-area')));
    return Offset(rect.left + rect.width * x, rect.top + rect.height * y);
  }

  Future<void> swipe(
    WidgetTester tester, {
    double endX = 0.5,
    double endY = 0.43,
    double startX = 0.5,
    double startY = 0.79,
  }) async {
    final gesture = await tester.startGesture(
      scenePoint(tester, startX, startY),
    );
    await gesture.moveTo(scenePoint(tester, endX, endY));
    await gesture.up();
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await start(tester);
    for (var i = 0; i < FrisbeeSession.throwCount; i++) {
      await swipe(tester);
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump();
  }

  void expectProductionArt(WidgetTester tester) {
    final sprite = find.byKey(const Key('frisbee-art'));
    expect(sprite, findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(of: sprite, matching: find.byType(Image)),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/things/toys_sheet.png',
    );
  }

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('start and gameplay fit ${size.width.toInt()}dp portrait', (
      tester,
    ) async {
      await mount(tester, size);
      expect(find.text('Игра с фрисби'), findsOneWidget);
      expect(find.text('Поиграем с Финни?'), findsOneWidget);
      expect(find.byKey(const Key('frisbee-room-background')), findsOneWidget);
      expect(find.byKey(const Key('frisbee-finny-stage-3')), findsOneWidget);
      expectProductionArt(tester);
      final header = tester.getRect(find.byKey(const Key('frisbee-header')));
      expect(header.left, 16);
      expect(size.width - header.right, 16);
      expect(header.top, greaterThanOrEqualTo(24));

      await start(tester);
      expect(find.text('Бросок 1 / 6'), findsOneWidget);
      expect(find.byKey(const Key('frisbee-gesture-area')), findsOneWidget);
      final scene = tester.getRect(
        find.byKey(const Key('frisbee-gesture-area')),
      );
      final target = tester.getRect(
        find.byKey(const Key('frisbee-catch-target')),
      );
      expect(
        target.width,
        closeTo(scene.width * FrisbeeSession.goodRadiusX * 2, 0.1),
      );
      expect(
        target.height,
        closeTo(scene.height * FrisbeeSession.goodRadiusY * 2, 0.1),
      );
      expect(rewardAttempts, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invalid and outside swipes do not consume a throw', (
    tester,
  ) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    await swipe(tester, startX: 0.1, endX: 0.1);
    expect(find.text('Бросок 1 / 6'), findsOneWidget);
    await swipe(tester, endY: 0.76);
    expect(find.text('Проведи пальцем чуть дальше.'), findsOneWidget);
    expect(find.text('Бросок 1 / 6'), findsOneWidget);
    await swipe(tester, endY: 0.95);
    expect(find.text('Проведи фрисби вверх, к Финни.'), findsOneWidget);
    expect(find.text('Бросок 1 / 6'), findsOneWidget);
    expect(rewardAttempts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('miss says approved «Почти!» and play continues', (tester) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    await swipe(tester, endX: 0.69, endY: 0.55);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Почти!'), findsOneWidget);
    expect(rewardAttempts, 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Бросок 2 / 6'), findsOneWidget);
  });

  testWidgets('result uses actual delta, then replay stays playable', (
    tester,
  ) async {
    await mount(tester, const Size(393, 852));
    await finish(tester);
    expect(find.text('Отличная игра!'), findsOneWidget);
    expect(find.text('Удачные броски'), findsOneWidget);
    expect(find.textContaining('/ 6'), findsWidgets);
    expect(find.text('Лучшая серия'), findsOneWidget);
    expect(find.text('Настроение Финни +40'), findsOneWidget);
    expect(rewardAttempts, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('frisbee-replay')));
    await tester.pump();
    expect(find.text('Бросок 1 / 6'), findsOneWidget);
    for (var i = 0; i < FrisbeeSession.throwCount; i++) {
      await swipe(tester);
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump();
    expect(rewardAttempts, 2);
    expect(
      find.textContaining('Награда за этот период уже получена'),
      findsOneWidget,
    );
    expect(find.text('Настроение Финни +40'), findsNothing);
    expect(submittedIds, ['widget-frisbee-0', 'widget-frisbee-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial cap shows real +5, not canonical +40', (tester) async {
    rewardCompletion = (_, _) async => const FrisbeeRewardResult(
      status: FrisbeeRewardStatus.applied,
      canonicalMoodEffect: 40,
      actualMoodDelta: 5,
      pet: _pet,
    );
    await mount(tester, const Size(360, 800));
    await finish(tester);
    expect(find.text('Настроение Финни +5'), findsOneWidget);
    expect(find.text('Настроение Финни +40'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mood cap is described without false increase', (tester) async {
    rewardCompletion = (_, _) async => const FrisbeeRewardResult(
      status: FrisbeeRewardStatus.capped,
      canonicalMoodEffect: 40,
      actualMoodDelta: 0,
      pet: _pet,
    );
    await mount(tester, const Size(360, 800));
    await finish(tester);
    expect(
      find.textContaining('Финни уже в отличном настроении'),
      findsOneWidget,
    );
    expect(find.text('Настроение Финни +40'), findsNothing);
    expect(
      tester.getBottomRight(find.byKey(const Key('frisbee-back-to-things'))).dy,
      lessThanOrEqualTo(776),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambiguous reward retry keeps the same session identity', (
    tester,
  ) async {
    rewardCompletion = (_, session) async {
      rewardAttempts++;
      submittedIds.add(session.sessionId);
      if (rewardAttempts == 1) throw StateError('ambiguous commit');
      return const FrisbeeRewardResult(
        status: FrisbeeRewardStatus.confirmedPreviously,
        canonicalMoodEffect: 40,
        actualMoodDelta: 0,
        pet: _pet,
      );
    };
    await mount(tester, const Size(360, 800));
    await finish(tester);
    expect(
      find.textContaining('Не удалось подтвердить награду'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('frisbee-retry-reward')));
    await tester.pump();
    expect(submittedIds, ['widget-frisbee-0', 'widget-frisbee-0']);
    expect(find.text('Награда за эту игру уже сохранена.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back and background before completion never submit reward', (
    tester,
  ) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    await swipe(tester);
    await tester.tap(find.byKey(const Key('frisbee-back')));
    await tester.pumpAndSettle();
    expect(find.text('Вещи открыты'), findsOneWidget);
    expect(rewardAttempts, 0);
  });

  testWidgets('background aborts unfinished run safely', (tester) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Игра прервалась. Начни заново!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(rewardAttempts, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unowned direct route is denied without starting', (
    tester,
  ) async {
    accessCheck = (_) async => throw PetItemNotOwnedException('toy_frisbee');
    await mount(tester, const Size(360, 800));
    expect(find.byKey(const Key('frisbee-access-denied')), findsOneWidget);
    expect(find.textContaining('сначала купи'), findsOneWidget);
    expect(find.byKey(const Key('frisbee-start')), findsNothing);
    expect(rewardAttempts, 0);
  });

  testWidgets('no active profile is denied safely', (tester) async {
    container.dispose();
    container = ProviderContainer(
      overrides: [activeProfileIdProvider.overrideWith(_NoActiveProfile.new)],
    );
    await mount(tester, const Size(360, 800));
    expect(find.byKey(const Key('frisbee-access-denied')), findsOneWidget);
    expect(find.textContaining('выбери профиль'), findsOneWidget);
    expect(rewardAttempts, 0);
  });

  testWidgets('profile switch aborts and cannot reward another profile', (
    tester,
  ) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    container.read(activeProfileIdProvider.notifier).setActiveProfileId(2);
    await tester.pump();
    expect(find.byKey(const Key('frisbee-access-denied')), findsOneWidget);
    expect(rewardAttempts, 0);
    expect(tester.takeException(), isNull);
  });
}
