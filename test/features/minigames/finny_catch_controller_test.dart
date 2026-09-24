import 'package:finny/features/minigames/finny_catch/finny_catch_controller.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
import 'package:finny/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime clock;
  late FinnyCatchController controller;
  late List<(String, int)> rewards;
  var nextRun = 0;
  var failReward = false;

  GameState savedState(int amount) => GameState(
    profileId: 7,
    walletBalance: amount,
    currentPeriod: 5,
    savedAmount: 0,
    updatedAt: clock,
  );

  setUp(() {
    clock = DateTime.utc(2026, 9, 24);
    rewards = [];
    nextRun = 0;
    failReward = false;
    controller = FinnyCatchController(
      profileId: 7,
      grantReward:
          ({required profileId, required amount, required runId}) async {
            rewards.add((runId, amount));
            if (failReward) throw StateError('database unavailable');
            return savedState(amount);
          },
      now: () => clock,
      runIdFactory: () => 'run-${nextRun++}',
      seedFactory: () => 42,
      autoTick: false,
    );
  });
  tearDown(() => controller.dispose());

  void elapse(Duration duration) {
    clock = clock.add(duration);
    controller.tick();
  }

  test('prepare is idle and countdown holds the game clock at 30 seconds', () {
    elapse(const Duration(seconds: 10));
    expect(controller.state.phase, FinnyCatchPhase.prepare);
    expect(controller.state.remainingSeconds, 30);
    expect(controller.state.objects, isEmpty);
    expect(rewards, isEmpty);
    controller.start();
    expect(controller.state.countdownText, '3');
    elapse(const Duration(milliseconds: 500));
    expect(controller.state.countdownText, '2');
    elapse(const Duration(milliseconds: 500));
    expect(controller.state.countdownText, '1');
    elapse(const Duration(milliseconds: 500));
    expect(controller.state.countdownText, 'Старт!');
    expect(controller.state.remainingSeconds, 30);
    expect(controller.state.objects, isEmpty);
    elapse(const Duration(milliseconds: 500));
    expect(controller.state.phase, FinnyCatchPhase.playing);
    expect(controller.state.remainingSeconds, 30);
  });

  test('pause freezes time, objects, movement and reward until resumed', () {
    controller.start();
    elapse(const Duration(seconds: 2));
    elapse(const Duration(seconds: 1));
    final before = controller.state;
    controller.pause();
    elapse(const Duration(seconds: 40));
    expect(controller.state.phase, FinnyCatchPhase.paused);
    expect(controller.state.remainingSeconds, before.remainingSeconds);
    expect(controller.state.objects.length, before.objects.length);
    controller.moveFinny(0.9);
    expect(controller.state.finnyX, before.finnyX);
    expect(rewards, isEmpty);
    controller.resume();
    elapse(const Duration(seconds: 1));
    expect(controller.state.phase, FinnyCatchPhase.playing);
    expect(
      controller.state.remainingSeconds,
      lessThan(before.remainingSeconds),
    );
  });

  test('Finny movement clamps to field edges', () {
    controller.setFieldWidth(360);
    controller.start();
    elapse(const Duration(seconds: 2));
    controller.moveFinny(-10);
    expect(controller.state.finnyX, greaterThan(0));
    controller.moveFinny(10);
    expect(controller.state.finnyX, lessThan(1));
  });

  test(
    'natural finish grants once; replay starts a new run in prepare',
    () async {
      controller.start();
      elapse(const Duration(seconds: 2));
      elapse(const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.phase, FinnyCatchPhase.result);
      expect(controller.state.remainingSeconds, 0);
      expect(controller.state.rewardAmount, 10);
      expect(controller.state.rewardGranted, isTrue);
      expect(rewards, [('run-0', 10)]);
      controller.tick();
      expect(rewards.length, 1);
      controller.replay();
      expect(controller.state.phase, FinnyCatchPhase.prepare);
      expect(controller.state.runId, 'run-1');
      expect(controller.state.remainingSeconds, 30);
      expect(controller.state.score, 0);
      expect(controller.state.objects, isEmpty);
      expect(controller.state.rewardAmount, isNull);
    },
  );

  test('early exit grants no partial reward', () {
    controller.start();
    elapse(const Duration(seconds: 2));
    elapse(const Duration(seconds: 10));
    controller.abort();
    elapse(const Duration(seconds: 100));
    expect(rewards, isEmpty);
  });

  test('failed save retains score, amount and run id for retry', () async {
    failReward = true;
    controller.start();
    elapse(const Duration(seconds: 2));
    elapse(const Duration(seconds: 30));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.rewardGranted, isFalse);
    expect(controller.state.rewardError, isNotNull);
    expect(controller.state.runId, 'run-0');
    controller.replay();
    expect(controller.state.phase, FinnyCatchPhase.result);
    failReward = false;
    await controller.retryReward();
    expect(controller.state.rewardGranted, isTrue);
    expect(rewards, [('run-0', 10), ('run-0', 10)]);
  });
}
