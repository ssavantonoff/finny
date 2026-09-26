import 'package:finny/features/minigames/frisbee/frisbee_session.dart';
import 'package:flutter_test/flutter_test.dart';

FrisbeeSession _session(int seed, {String suffix = ''}) =>
    FrisbeeSession(seed: seed, sessionId: 'frisbee-$seed$suffix')..start();

/// Aim for a chosen horizontal offset from the current Finny target.
FrisbeePoint _aim(FrisbeeSession session, double offset) {
  const upward = 0.4;
  final targetX = session.currentTarget.x + offset;
  final travelY = FrisbeeSession.launchPoint.y - session.currentTarget.y;
  final dx = (targetX - FrisbeeSession.launchPoint.x) * upward / travelY;
  return FrisbeePoint(
    FrisbeeSession.launchPoint.x + dx,
    FrisbeeSession.launchPoint.y - upward,
  );
}

void _throw(FrisbeeSession session, double offset, {int pointer = 1}) {
  expect(session.beginGesture(pointer, FrisbeeSession.launchPoint), isTrue);
  expect(
    session.releaseGesture(pointer, _aim(session, offset), session.elapsed),
    FrisbeeGestureResult.launched,
  );
}

void _resolve(FrisbeeSession session) {
  session.advance(session.nextReadyAt!);
}

void main() {
  test('fresh session has six seeded, bounded targets and no completion', () {
    for (final seed in [0, 1, 42, 10000]) {
      final first = _session(seed);
      final second = _session(seed);
      expect(first.phase, FrisbeeSessionPhase.ready);
      expect(first.resolvedCount, 0);
      expect(first.throwNumber, 1);
      expect(first.successfulThrows, 0);
      expect(first.bestStreak, 0);
      expect(first.completion, isNull);
      expect(first.canSubmitReward, isFalse);
      expect(first.targets, second.targets);
      expect(first.targets.length, FrisbeeSession.throwCount);
      for (final target in first.targets) {
        expect(target.x, inInclusiveRange(0.4, 0.6));
        expect(target.y, 0.31);
      }
    }
    expect(_session(1).targets, isNot(_session(2).targets));
  });

  test('only a pointer beginning inside the launch zone can aim', () {
    final session = _session(3);
    expect(session.beginGesture(1, const FrisbeePoint(0.1, 0.1)), isFalse);
    expect(session.phase, FrisbeeSessionPhase.ready);
    expect(
      session.releaseGesture(1, const FrisbeePoint(0.5, 0.3), Duration.zero),
      FrisbeeGestureResult.ignored,
    );
    expect(session.resolvedCount, 0);
    expect(
      session.beginGesture(
        1,
        FrisbeePoint(
          FrisbeeSession.launchPoint.x + FrisbeeSession.launchHalfWidth,
          FrisbeeSession.launchPoint.y + FrisbeeSession.launchHalfHeight,
        ),
      ),
      isTrue,
    );
  });

  test('short and insufficiently upward swipes spend no throw', () {
    final session = _session(4);
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isTrue);
    expect(
      session.releaseGesture(1, const FrisbeePoint(0.51, 0.75), Duration.zero),
      FrisbeeGestureResult.invalidShort,
    );
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isTrue);
    expect(
      session.releaseGesture(1, const FrisbeePoint(0.85, 0.79), Duration.zero),
      FrisbeeGestureResult.invalidDirection,
    );
    expect(session.phase, FrisbeeSessionPhase.ready);
    expect(session.resolvedCount, 0);
    expect(session.throwNumber, 1);
    expect(session.successfulThrows, 0);
    expect(session.bestStreak, 0);
    expect(session.completion, isNull);
  });

  test('non-finite input is ignored; drag may leave the widget bounds', () {
    final session = _session(4, suffix: '-bounds');
    expect(
      session.beginGesture(1, const FrisbeePoint(double.nan, 0.79)),
      isFalse,
    );
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isTrue);
    expect(
      session.updateGesture(1, const FrisbeePoint(double.nan, 0.3)),
      isFalse,
    );
    expect(
      session.releaseGesture(
        1,
        const FrisbeePoint(double.infinity, 0.3),
        Duration.zero,
      ),
      FrisbeeGestureResult.invalidDirection,
    );
    expect(session.resolvedCount, 0);
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isTrue);
    expect(
      session.releaseGesture(1, const FrisbeePoint(1.5, -0.5), Duration.zero),
      FrisbeeGestureResult.launched,
    );
    expect(session.landingPoint!.x, inInclusiveRange(0, 1));
    expect(session.landingPoint!.y, inInclusiveRange(0, 1));
    _resolve(session);
    expect(session.resolvedCount, 1);
  });

  test('one pointer owns a gesture; cancel does not spend a throw', () {
    final session = _session(5);
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isTrue);
    expect(session.beginGesture(2, FrisbeeSession.launchPoint), isFalse);
    expect(session.updateGesture(2, const FrisbeePoint(0.5, 0.4)), isFalse);
    expect(
      session.releaseGesture(2, const FrisbeePoint(0.5, 0.4), Duration.zero),
      FrisbeeGestureResult.ignored,
    );
    expect(session.phase, FrisbeeSessionPhase.aiming);
    expect(session.updateGesture(1, const FrisbeePoint(0.5, 0.4)), isTrue);
    expect(session.gesturePosition, const FrisbeePoint(0.5, 0.4));
    session.cancelGesture(2);
    expect(session.phase, FrisbeeSessionPhase.aiming);
    session.cancelGesture(1);
    expect(session.phase, FrisbeeSessionPhase.ready);
    expect(session.resolvedCount, 0);
    expect(session.gesturePosition, isNull);
  });

  test('gesture and target geometry classify Perfect, Good and Miss', () {
    for (final (offset, outcome) in [
      (0.0, FrisbeeOutcome.perfect),
      (0.13, FrisbeeOutcome.good),
      (0.29, FrisbeeOutcome.miss),
    ]) {
      final session = _session(6, suffix: '-$offset');
      _throw(session, offset);
      expect(session.phase, FrisbeeSessionPhase.flying);
      expect(session.resolvedCount, 0);
      _resolve(session);
      expect(session.outcomes, [outcome]);
      expect(session.lastOutcome, outcome);
      expect(session.phase, FrisbeeSessionPhase.ready);
    }

    final sameGestureOne = _session(7);
    final sameGestureTwo = _session(7);
    _throw(sameGestureOne, 0.0);
    _throw(sameGestureTwo, 0.0);
    expect(sameGestureOne.landingPoint, sameGestureTwo.landingPoint);
    _resolve(sameGestureOne);
    _resolve(sameGestureTwo);
    expect(sameGestureOne.outcomes, sameGestureTwo.outcomes);
  });

  test('input is locked in flight and feedback, including extra pointers', () {
    final session = _session(8);
    final target = session.currentTarget;
    _throw(session, 0.0);
    final landing = session.landingPoint;
    for (var pointer = 2; pointer < 50; pointer++) {
      expect(
        session.beginGesture(pointer, FrisbeeSession.launchPoint),
        isFalse,
      );
      expect(
        session.releaseGesture(pointer, _aim(session, 0.0), session.elapsed),
        FrisbeeGestureResult.ignored,
      );
    }
    expect(session.landingPoint, landing);
    expect(session.resolvedCount, 0);
    final feedbackStart =
        session.nextReadyAt! - FrisbeeSession.feedbackDuration;
    session.advance(feedbackStart);
    expect(session.phase, FrisbeeSessionPhase.feedback);
    expect(session.resolvedCount, 1);
    expect(session.throwNumber, 1);
    expect(session.currentTarget, target);
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isFalse);
    expect(
      session.releaseGesture(1, _aim(session, 0.0), session.elapsed),
      FrisbeeGestureResult.ignored,
    );
    expect(session.resolvedCount, 1);
    _resolve(session);
    expect(session.throwNumber, 2);
    expect(session.currentTarget, session.targets[1]);
  });

  test('flight path is bounded, time based, and frame independent', () {
    final largeStep = _session(9);
    final smallSteps = _session(9);
    _throw(largeStep, 0.1);
    _throw(smallSteps, 0.1);
    expect(largeStep.flightPosition, FrisbeeSession.launchPoint);
    final flightEnd = largeStep.nextReadyAt! - FrisbeeSession.feedbackDuration;
    final halfway = Duration(microseconds: flightEnd.inMicroseconds ~/ 2);
    largeStep.advance(halfway);
    smallSteps.advance(halfway);
    final halfwayPosition = largeStep.flightPosition!;
    expect(halfwayPosition, smallSteps.flightPosition);
    expect(halfwayPosition.x, inInclusiveRange(0.0, 1.0));
    expect(halfwayPosition.y, inInclusiveRange(0.0, 1.0));
    final end = largeStep.nextReadyAt!;
    largeStep.advance(end);
    var elapsed = halfway;
    while (elapsed < end) {
      elapsed += const Duration(milliseconds: 13);
      smallSteps.advance(elapsed < end ? elapsed : end);
    }
    expect(largeStep.phase, smallSteps.phase);
    expect(largeStep.outcomes, smallSteps.outcomes);
    expect(largeStep.elapsed, smallSteps.elapsed);
    expect(largeStep.flightPosition, isNull);
  });

  test('six valid throws score successes, streak, and complete once', () {
    final session = _session(10);
    final wanted = [
      FrisbeeOutcome.perfect,
      FrisbeeOutcome.good,
      FrisbeeOutcome.miss,
      FrisbeeOutcome.good,
      FrisbeeOutcome.perfect,
      FrisbeeOutcome.good,
    ];
    for (var index = 0; index < FrisbeeSession.throwCount; index++) {
      expect(session.throwNumber, index + 1);
      final offset = switch (wanted[index]) {
        FrisbeeOutcome.perfect => 0.0,
        FrisbeeOutcome.good => 0.13,
        FrisbeeOutcome.miss => 0.29,
      };
      _throw(session, offset);
      expect(session.canSubmitReward, isFalse);
      expect(session.completion, isNull);
      _resolve(session);
    }
    expect(session.phase, FrisbeeSessionPhase.completed);
    expect(session.resolvedCount, 6);
    expect(session.outcomes, wanted);
    expect(session.successfulThrows, 5);
    expect(session.bestStreak, 3);
    expect(session.canSubmitReward, isTrue);
    final completion = session.completion!;
    expect(completion.sessionId, session.sessionId);
    expect(completion.successfulThrows, 5);
    expect(completion.bestStreak, 3);
    expect(completion.totalThrows, 6);
    expect(session.throwNumber, 6);
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isFalse);
    expect(
      session.releaseGesture(1, _aim(session, 0), session.elapsed),
      FrisbeeGestureResult.ignored,
    );
    session.advance(session.elapsed + const Duration(days: 1));
    session.abort();
    expect(session.resolvedCount, 6);
    expect(identical(session.completion, completion), isTrue);
  });

  test('a miss resets streak but cannot end or punish a session', () {
    final session = _session(11);
    _throw(session, 0.0);
    _resolve(session);
    expect(session.bestStreak, 1);
    _throw(session, 0.29);
    _resolve(session);
    expect(session.phase, FrisbeeSessionPhase.ready);
    expect(session.resolvedCount, 2);
    expect(session.successfulThrows, 1);
    expect(session.bestStreak, 1);
    _throw(session, 0.0);
    _resolve(session);
    expect(session.bestStreak, 1);
  });

  test('abort before completion discards flight and cannot submit reward', () {
    final session = _session(12);
    _throw(session, 0.0);
    session.abort();
    session.advance(const Duration(hours: 1));
    expect(session.phase, FrisbeeSessionPhase.aborted);
    expect(session.resolvedCount, 0);
    expect(session.completion, isNull);
    expect(session.canSubmitReward, isFalse);
    expect(session.beginGesture(1, FrisbeeSession.launchPoint), isFalse);
    expect(() => session.start(), throwsStateError);
    final replay = _session(12, suffix: '-replay');
    expect(replay.resolvedCount, 0);
    expect(replay.sessionId, isNot(session.sessionId));
  });

  test('session ID and elapsed time are validated', () {
    expect(
      () => FrisbeeSession(seed: 1, sessionId: '   '),
      throwsArgumentError,
    );
    final session = _session(13);
    session.advance(const Duration(milliseconds: 50));
    expect(
      () => session.advance(const Duration(milliseconds: 49)),
      throwsArgumentError,
    );
  });
}
