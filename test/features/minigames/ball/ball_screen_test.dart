import 'package:finny/app/providers.dart';
import 'package:finny/features/minigames/ball/ball_screen.dart';
import 'package:finny/features/minigames/ball/ball_session.dart';
import 'package:finny/models/ball_reward.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _access = BallGameAccess(
  profileId: 1,
  mode: BallGameMode.campaign,
  periodId: 10,
  canonicalMoodEffect: 35,
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

class _ActiveBallProfile extends ActiveProfileIdController {
  @override
  int? build() => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late GoRouter router;
  late Future<BallGameAccess> Function(int) accessCheck;
  late Future<BallRewardResult> Function(BallGameAccess, BallSession)
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
      return BallRewardResult(
        status: rewardAttempts == 1
            ? BallRewardStatus.applied
            : BallRewardStatus.alreadyRewarded,
        canonicalMoodEffect: 35,
        actualMoodDelta: rewardAttempts == 1 ? 35 : 0,
        pet: _pet.copyWith(mood: 75),
      );
    };
    container = ProviderContainer(
      overrides: [activeProfileIdProvider.overrideWith(_ActiveBallProfile.new)],
    );
    router = GoRouter(
      initialLocation: '/toy-ball',
      routes: [
        GoRoute(
          path: '/toy-ball',
          builder: (_, _) => BallScreen(
            checkAccess: (profileId) => accessCheck(profileId),
            completeSession: (access, session) =>
                rewardCompletion(access, session),
            loadPet: (_) async => _pet,
            seedFactory: () => 42,
            sessionIdFactory: () => 'widget-ball-${sessionNumber++}',
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

  Future<void> finishByTimeout(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ball-start')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
  }

  testWidgets('start screen uses production room and Finny at 360x800', (
    tester,
  ) async {
    await mount(tester, const Size(360, 800));
    expect(find.text('Игра с мячом'), findsOneWidget);
    expect(find.text('Поиграем с Финни?'), findsOneWidget);
    expect(
      find.text('Нажимай, когда мяч окажется в зоне удара.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ball-room-background')), findsOneWidget);
    expect(find.byKey(const Key('ball-finny-stage-3')), findsOneWidget);
    expect(find.byKey(const Key('ball-placeholder-art')), findsOneWidget);
    expect(find.byKey(const Key('ball-start')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('ball-back'))).dy,
      greaterThanOrEqualTo(24),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active game shows timing zone and grants nothing before completion',
    (tester) async {
      await mount(tester, const Size(360, 800));
      await tester.tap(find.byKey(const Key('ball-start')));
      await tester.pump();
      expect(find.byKey(const Key('ball-progress')), findsOneWidget);
      expect(find.byKey(const Key('ball-timing-zone')), findsOneWidget);
      expect(find.byKey(const Key('ball-tap-area')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(find.byKey(const Key('ball-tap-area')));
      await tester.pump();
      expect(find.byKey(const Key('ball-feedback')), findsOneWidget);
      expect(rewardAttempts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('result, reward feedback and replay fit a tall portrait size', (
    tester,
  ) async {
    await mount(tester, const Size(393, 852));
    await finishByTimeout(tester);
    expect(find.text('Отличная игра!'), findsOneWidget);
    expect(find.text('Точные передачи'), findsOneWidget);
    expect(find.text('0 / 8'), findsOneWidget);
    expect(find.text('Лучшая серия'), findsOneWidget);
    expect(find.text('Настроение Финни +35'), findsOneWidget);
    expect(rewardAttempts, 1);
    expect(find.byKey(const Key('ball-replay')), findsOneWidget);
    expect(find.byKey(const Key('ball-back-to-things')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('ball-replay')));
    await tester.pump();
    expect(find.text('Отличная игра!'), findsNothing);
    expect(find.text('1 / 8'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(rewardAttempts, 2);
    expect(find.textContaining('Награда за этот'), findsOneWidget);
    expect(submittedIds, ['widget-ball-0', 'widget-ball-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back before completion leaves without reward', (tester) async {
    await mount(tester, const Size(360, 800));
    await tester.tap(find.byKey(const Key('ball-start')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ball-back')));
    await tester.pumpAndSettle();
    expect(find.text('Вещи открыты'), findsOneWidget);
    expect(rewardAttempts, 0);
  });

  testWidgets('background aborts unfinished run without reward', (
    tester,
  ) async {
    await mount(tester, const Size(360, 800));
    await tester.tap(find.byKey(const Key('ball-start')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Игра прервалась. Начни заново!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 35));
    expect(rewardAttempts, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct route without ownership shows safe fallback', (
    tester,
  ) async {
    accessCheck = (_) async => throw PetItemNotOwnedException('toy_ball');
    await mount(tester, const Size(360, 800));
    expect(find.byKey(const Key('ball-access-denied')), findsOneWidget);
    expect(find.textContaining('сначала купи'), findsOneWidget);
    expect(find.byKey(const Key('ball-start')), findsNothing);
    expect(rewardAttempts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('temporary reward error retries the same completed session', (
    tester,
  ) async {
    rewardCompletion = (_, session) async {
      rewardAttempts++;
      submittedIds.add(session.sessionId);
      if (rewardAttempts == 1) throw StateError('ambiguous database result');
      return const BallRewardResult(
        status: BallRewardStatus.confirmedPreviously,
        canonicalMoodEffect: 35,
        actualMoodDelta: 0,
        pet: _pet,
      );
    };
    await mount(tester, const Size(360, 800));
    await finishByTimeout(tester);
    expect(
      find.textContaining('Не удалось подтвердить награду'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ball-retry-reward')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ball-retry-reward')));
    await tester.pump();
    expect(rewardAttempts, 2);
    expect(submittedIds, ['widget-ball-0', 'widget-ball-0']);
    expect(find.text('Награда за эту игру уже сохранена.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capped reward does not claim a +35 mood increase', (
    tester,
  ) async {
    rewardCompletion = (_, _) async {
      rewardAttempts++;
      return const BallRewardResult(
        status: BallRewardStatus.capped,
        canonicalMoodEffect: 35,
        actualMoodDelta: 0,
        pet: _pet,
      );
    };
    await mount(tester, const Size(360, 800));
    await finishByTimeout(tester);
    expect(
      find.textContaining('Финни уже в отличном настроении'),
      findsOneWidget,
    );
    expect(find.textContaining('Настроение Финни +35'), findsNothing);
    expect(
      tester.getBottomRight(find.byKey(const Key('ball-back-to-things'))).dy,
      lessThanOrEqualTo(776),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile switch invalidates the open game and blocks reward', (
    tester,
  ) async {
    await mount(tester, const Size(360, 800));
    await tester.tap(find.byKey(const Key('ball-start')));
    await tester.pump();
    container.read(activeProfileIdProvider.notifier).setActiveProfileId(2);
    await tester.pump();
    expect(find.byKey(const Key('ball-access-denied')), findsOneWidget);
    expect(rewardAttempts, 0);
    expect(tester.takeException(), isNull);
  });
}
