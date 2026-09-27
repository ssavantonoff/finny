import 'package:finny/app/providers.dart';
import 'package:finny/features/minigames/car/car_screen.dart';
import 'package:finny/features/minigames/car/car_session.dart';
import 'package:finny/models/car_reward.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _access = CarGameAccess(
  profileId: 1,
  mode: CarGameMode.campaign,
  periodId: 10,
  canonicalMoodEffect: 30,
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

class _ActiveCarProfile extends ActiveProfileIdController {
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
  late Future<CarGameAccess> Function(int) accessCheck;
  late Future<CarRewardResult> Function(CarGameAccess, CarSession)
  rewardCompletion;
  var rewardAttempts = 0;
  var sessionNumber = 0;
  var gameSeed = 42;
  final submittedIds = <String>[];

  setUp(() {
    rewardAttempts = 0;
    sessionNumber = 0;
    gameSeed = 42;
    submittedIds.clear();
    accessCheck = (_) async => _access;
    rewardCompletion = (access, session) async {
      rewardAttempts++;
      submittedIds.add(session.sessionId);
      return CarRewardResult(
        status: rewardAttempts == 1
            ? CarRewardStatus.applied
            : CarRewardStatus.alreadyRewarded,
        canonicalMoodEffect: 30,
        actualMoodDelta: rewardAttempts == 1 ? 30 : 0,
        pet: _pet.copyWith(mood: 70),
      );
    };
    container = ProviderContainer(
      overrides: [activeProfileIdProvider.overrideWith(_ActiveCarProfile.new)],
    );
    router = GoRouter(
      initialLocation: '/toy-car',
      routes: [
        GoRoute(
          path: '/toy-car',
          builder: (_, _) => CarScreen(
            checkAccess: (profileId) => accessCheck(profileId),
            completeSession: (access, session) =>
                rewardCompletion(access, session),
            loadPet: (_) async => _pet,
            seedFactory: () => gameSeed,
            sessionIdFactory: () => 'widget-car-${sessionNumber++}',
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
    await tester.tap(find.byKey(const Key('car-start')));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await start(tester);
    await tester.pump(const Duration(seconds: 40));
    await tester.pump();
  }

  Offset scenePoint(WidgetTester tester, double x, double y) {
    final rect = tester.getRect(find.byKey(const Key('car-steering-area')));
    return Offset(rect.left + rect.width * x, rect.top + rect.height * y);
  }

  void expectProductionArt(WidgetTester tester) {
    final sprite = find.byKey(const Key('car-production-art')).first;
    final image = tester.widget<Image>(
      find.descendant(of: sprite, matching: find.byType(Image)),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/things/toys_sheet.png',
    );
  }

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets(
      'start, driving and result fit ${size.width.toInt()}dp portrait',
      (tester) async {
        await mount(tester, size);
        expect(find.text('Игра с машинкой'), findsOneWidget);
        expect(find.text('Поиграем с Финни?'), findsOneWidget);
        expect(find.byKey(const Key('car-room-background')), findsOneWidget);
        expect(find.byKey(const Key('car-finny-stage-3')), findsOneWidget);
        expectProductionArt(tester);
        final header = tester.getRect(find.byKey(const Key('car-header')));
        expect(header.left, 16);
        expect(size.width - header.right, 16);
        expect(header.top, greaterThanOrEqualTo(24));
        expect(tester.takeException(), isNull);

        await start(tester);
        expect(find.text('Участок 1 / 6'), findsOneWidget);
        expect(find.byKey(const Key('car-steering-area')), findsOneWidget);
        expect(find.byKey(const Key('car-track')), findsOneWidget);
        expect(find.byKey(const Key('car-top-down-art')), findsOneWidget);
        expect(find.byKey(const Key('car-tutorial-hint')), findsOneWidget);
        expect(rewardAttempts, 0);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(seconds: 40));
        await tester.pump();
        expect(find.text('Отличная поездка!'), findsOneWidget);
        expect(find.text('Удачные проезды'), findsOneWidget);
        expect(find.text('Лучшая серия'), findsOneWidget);
        expect(find.text('Настроение Финни +30'), findsOneWidget);
        expect(
          tester.getBottomRight(find.byKey(const Key('car-back-to-things'))).dy,
          lessThanOrEqualTo(size.height - 24),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('short landscape keeps start, track and result reachable', (
    tester,
  ) async {
    const size = Size(800, 360);
    await mount(tester, size);
    expect(find.byKey(const Key('car-compact-start')), findsOneWidget);
    expect(find.byKey(const Key('car-start')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await start(tester);
    final field = tester.getRect(find.byKey(const Key('car-steering-area')));
    expect(field.width, lessThan(440));
    expect(field.height, lessThan(240));
    expect(find.byKey(const Key('car-top-down-art')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 40));
    await tester.pump();
    expect(find.byKey(const Key('car-result-scroll')), findsOneWidget);
    expect(find.byKey(const Key('car-back-to-things')), findsOneWidget);
    expect(
      tester.getBottomRight(find.byKey(const Key('car-back-to-things'))).dy,
      lessThanOrEqualTo(size.height - 24),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'horizontal drag steers, while secondary pointer cannot jump car',
    (tester) async {
      await mount(tester, const Size(393, 852));
      await start(tester);
      final before = tester
          .getCenter(find.byKey(const Key('car-top-down-art')))
          .dx;
      final first = await tester.startGesture(
        scenePoint(tester, 0.5, 0.7),
        pointer: 1,
      );
      final second = await tester.startGesture(
        scenePoint(tester, 0.5, 0.7),
        pointer: 2,
      );
      await second.moveTo(scenePoint(tester, 0.95, 0.7));
      await tester.pump(const Duration(milliseconds: 100));
      final afterSecondary = tester
          .getCenter(find.byKey(const Key('car-top-down-art')))
          .dx;
      expect((afterSecondary - before).abs(), lessThan(16));

      await first.moveTo(scenePoint(tester, 0.85, 0.7));
      await tester.pump(const Duration(milliseconds: 500));
      final afterPrimary = tester
          .getCenter(find.byKey(const Key('car-top-down-art')))
          .dx;
      expect(afterPrimary, greaterThan(afterSecondary));
      expect(afterPrimary - before, lessThan(140));
      await second.up();
      await first.up();
      expect(rewardAttempts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sections advance through feedback with visible progress', (
    tester,
  ) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    expect(find.text('Участок 1 / 6'), findsOneWidget);
    await tester.pump(CarSession.sectionDuration);
    expect(find.byKey(const Key('car-feedback')), findsOneWidget);
    expect(find.text('Участок 1 / 6'), findsOneWidget);
    expect(find.byKey(const Key('car-tutorial-hint')), findsNothing);
    expect(rewardAttempts, 0);
    await tester.pump(CarSession.feedbackDuration);
    expect(find.text('Участок 2 / 6'), findsOneWidget);
    expect(find.byKey(const Key('car-feedback')), findsNothing);
    expect(find.byKey(const Key('car-result')), findsNothing);
  });

  testWidgets('a central steering path gives Perfect feedback', (tester) async {
    await mount(tester, const Size(393, 852));
    await start(tester);
    final track = CarSession(seed: gameSeed, sessionId: 'track').sections.first;
    final gesture = await tester.startGesture(scenePoint(tester, 0.5, 0.7));
    for (var step = 1; step <= 20; step++) {
      await gesture.moveTo(scenePoint(tester, track.centerAt(step / 20), 0.7));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Идеально!'), findsOneWidget);
    await gesture.up();
    expect(rewardAttempts, 0);
  });

  testWidgets('an off-center clear path gives Good feedback', (tester) async {
    await mount(tester, const Size(393, 852));
    await start(tester);
    final track = CarSession(seed: gameSeed, sessionId: 'track').sections.first;
    final gesture = await tester.startGesture(scenePoint(tester, 0.5, 0.7));
    for (var step = 1; step <= 20; step++) {
      await gesture.moveTo(
        scenePoint(tester, track.centerAt(step / 20) + 0.08, 0.7),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Хорошо!'), findsOneWidget);
    await gesture.up();
    expect(rewardAttempts, 0);
  });

  testWidgets('driving into the border gives Miss and play continues', (
    tester,
  ) async {
    await mount(tester, const Size(393, 852));
    await start(tester);
    final gesture = await tester.startGesture(scenePoint(tester, 0.5, 0.7));
    await gesture.moveTo(scenePoint(tester, 0.95, 0.7));
    await tester.pump(CarSession.sectionDuration);
    expect(find.text('Почти!'), findsOneWidget);
    await gesture.up();
    await tester.pump(CarSession.feedbackDuration);
    expect(find.text('Участок 2 / 6'), findsOneWidget);
    expect(rewardAttempts, 0);
  });

  testWidgets('cancel releases the active steering pointer', (tester) async {
    await mount(tester, const Size(393, 852));
    await start(tester);
    final first = await tester.startGesture(scenePoint(tester, 0.5, 0.7));
    await first.moveTo(scenePoint(tester, 0.9, 0.7));
    await tester.pump(const Duration(milliseconds: 120));
    await first.cancel();
    final afterCancel = tester
        .getCenter(find.byKey(const Key('car-top-down-art')))
        .dx;
    final next = await tester.startGesture(scenePoint(tester, 0.5, 0.7));
    await next.moveTo(scenePoint(tester, 0.2, 0.7));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getCenter(find.byKey(const Key('car-top-down-art'))).dx,
      lessThan(afterCancel),
    );
    await next.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'six sections complete once; replay gets a new session identity',
    (tester) async {
      await mount(tester, const Size(393, 852));
      await finish(tester);
      expect(rewardAttempts, 1);
      expect(submittedIds, ['widget-car-0']);
      await tester.pump(const Duration(seconds: 3));
      expect(rewardAttempts, 1);
      await tester.tap(find.byKey(const Key('car-replay')));
      await tester.pump();
      expect(find.text('Участок 1 / 6'), findsOneWidget);
      await tester.pump(const Duration(seconds: 40));
      await tester.pump();
      expect(rewardAttempts, 2);
      expect(submittedIds, ['widget-car-0', 'widget-car-1']);
      expect(find.text('Настроение Финни +30'), findsNothing);
      expect(
        find.textContaining('Награда за этот период уже получена'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('partial cap shows actual increase', (tester) async {
    rewardCompletion = (_, _) async => const CarRewardResult(
      status: CarRewardStatus.applied,
      canonicalMoodEffect: 30,
      actualMoodDelta: 5,
      pet: _pet,
    );
    await mount(tester, const Size(360, 800));
    await finish(tester);
    expect(find.text('Настроение Финни +5'), findsOneWidget);
    expect(find.text('Настроение Финни +30'), findsNothing);
  });

  testWidgets('mood cap and free play limit have honest messages', (
    tester,
  ) async {
    rewardCompletion = (_, _) async => const CarRewardResult(
      status: CarRewardStatus.capped,
      canonicalMoodEffect: 30,
      actualMoodDelta: 0,
      pet: _pet,
    );
    await mount(tester, const Size(360, 800));
    await finish(tester);
    expect(
      find.textContaining('Финни уже в отличном настроении'),
      findsOneWidget,
    );
    expect(find.text('Настроение Финни +30'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambiguous reward retry keeps the same operation identity', (
    tester,
  ) async {
    rewardCompletion = (_, session) async {
      rewardAttempts++;
      submittedIds.add(session.sessionId);
      if (rewardAttempts == 1) throw StateError('ambiguous commit');
      return const CarRewardResult(
        status: CarRewardStatus.confirmedPreviously,
        canonicalMoodEffect: 30,
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
    await tester.tap(find.byKey(const Key('car-retry-reward')));
    await tester.pump();
    expect(submittedIds, ['widget-car-0', 'widget-car-0']);
    expect(find.text('Награда за эту игру уже сохранена.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back before completion exits without reward', (tester) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('car-back')));
    await tester.pumpAndSettle();
    expect(find.text('Вещи открыты'), findsOneWidget);
    expect(rewardAttempts, 0);
  });

  testWidgets('result returns to Things', (tester) async {
    await mount(tester, const Size(360, 800));
    await finish(tester);
    await tester.tap(find.byKey(const Key('car-back-to-things')));
    await tester.pumpAndSettle();
    expect(find.text('Вещи открыты'), findsOneWidget);
    expect(rewardAttempts, 1);
  });

  testWidgets('background aborts an unfinished ride', (tester) async {
    await mount(tester, const Size(360, 800));
    await start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Игра прервалась. Начни заново!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 40));
    expect(rewardAttempts, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unowned direct route cannot start', (tester) async {
    accessCheck = (_) async => throw PetItemNotOwnedException('toy_plush');
    await mount(tester, const Size(360, 800));
    expect(find.byKey(const Key('car-access-denied')), findsOneWidget);
    expect(find.textContaining('сначала купи'), findsOneWidget);
    expect(find.byKey(const Key('car-start')), findsNothing);
    expect(rewardAttempts, 0);
  });

  testWidgets('no active profile cannot start', (tester) async {
    container.dispose();
    container = ProviderContainer(
      overrides: [activeProfileIdProvider.overrideWith(_NoActiveProfile.new)],
    );
    await mount(tester, const Size(360, 800));
    expect(find.byKey(const Key('car-access-denied')), findsOneWidget);
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
    expect(find.byKey(const Key('car-access-denied')), findsOneWidget);
    await tester.pump(const Duration(seconds: 40));
    expect(rewardAttempts, 0);
    expect(tester.takeException(), isNull);
  });
}
