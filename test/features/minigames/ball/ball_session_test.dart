import 'package:finny/features/minigames/ball/ball_session.dart';
import 'package:flutter_test/flutter_test.dart';

BallSession _session(int seed, {String suffix = ''}) =>
    BallSession(seed: seed, sessionId: 'test-$seed$suffix');

Duration _part(Duration whole, double fraction) =>
    Duration(microseconds: (whole.inMicroseconds * fraction).round());

BallOutcome? _tapAtProgress(BallSession session, double progress) =>
    session.tap(
      session.elapsed +
          _part(session.currentOpportunity.flightDuration, progress),
    );

void _next(BallSession session) {
  session.advance(session.nextOpportunityAt!);
}

void main() {
  test('same seed yields the same eight bounded flights', () {
    for (final seed in [0, 1, 42, 10000]) {
      final first = _session(seed).opportunities;
      final second = _session(seed).opportunities;
      expect(first.length, 8);
      expect(first.map((flight) => flight.number), [1, 2, 3, 4, 5, 6, 7, 8]);
      for (var index = 0; index < first.length; index++) {
        expect(first[index].flightDuration, second[index].flightDuration);
        expect(first[index].horizontalOffset, second[index].horizontalOffset);
        expect(
          first[index].flightDuration.inMilliseconds,
          inInclusiveRange(1550, 2275),
        );
        expect(first[index].horizontalOffset, inInclusiveRange(-0.12, 0.12));
      }
      expect(first.last.flightDuration, lessThan(first.first.flightDuration));
    }
    final seedOne = _session(1).opportunities;
    final seedTwo = _session(2).opportunities;
    expect(
      seedOne.map((flight) => flight.horizontalOffset),
      isNot(seedTwo.map((flight) => flight.horizontalOffset)),
    );
  });

  test('early, good, perfect, late and timeout resolve exactly once', () {
    final session = _session(7);
    expect(session.phase, BallSessionPhase.notStarted);
    expect(session.tap(Duration.zero), isNull);
    expect(session.canSubmitReward, isFalse);
    session.start();

    expect(_tapAtProgress(session, 0.1), BallOutcome.miss);
    expect(session.phase, BallSessionPhase.feedback);
    expect(session.tap(session.elapsed), isNull);
    expect(session.resolvedCount, 1);
    _next(session);

    expect(_tapAtProgress(session, 0.55), BallOutcome.good);
    _next(session);
    expect(_tapAtProgress(session, 0.7), BallOutcome.perfect);
    _next(session);
    expect(_tapAtProgress(session, 0.91), BallOutcome.miss);
    _next(session);

    session.advance(
      session.elapsed + session.currentOpportunity.flightDuration,
    );
    expect(session.lastOutcome, BallOutcome.miss);
    expect(session.tap(session.elapsed), isNull);
    expect(session.resolvedCount, 5);
    expect(session.accuratePasses, 2);
    expect(session.bestStreak, 2);
    expect(session.phase, BallSessionPhase.feedback);
    expect(session.canSubmitReward, isFalse);
  });

  test(
    'miss continues; eight returns complete with accurate count and streak',
    () {
      final session = _session(99)..start();
      final wanted = [
        BallOutcome.perfect,
        BallOutcome.good,
        BallOutcome.miss,
        BallOutcome.good,
        BallOutcome.perfect,
        BallOutcome.good,
        BallOutcome.miss,
        BallOutcome.perfect,
      ];
      for (var index = 0; index < 8; index++) {
        expect(session.opportunityNumber, index + 1);
        expect(session.phase, BallSessionPhase.active);
        final progress = switch (wanted[index]) {
          BallOutcome.perfect => 0.7,
          BallOutcome.good => 0.55,
          BallOutcome.miss => 0.1,
        };
        expect(_tapAtProgress(session, progress), wanted[index]);
        expect(session.canSubmitReward, isFalse);
        expect(session.completion, isNull);
        expect(session.tap(session.elapsed), isNull);
        _next(session);
      }
      expect(session.phase, BallSessionPhase.completed);
      expect(session.canSubmitReward, isTrue);
      expect(session.resolvedCount, 8);
      expect(session.outcomes, wanted);
      expect(session.accuratePasses, 6);
      expect(session.bestStreak, 3);
      expect(session.completion?.sessionId, 'test-99');
      expect(session.completion?.accuratePasses, 6);
      expect(session.completion?.bestStreak, 3);
      expect(session.completion?.totalPasses, 8);
      expect(session.tap(session.elapsed), isNull);
      expect(session.resolvedCount, 8);
      expect(session.completion?.sessionId, 'test-99');
    },
  );

  test('large time jump and small steps produce the same timeout result', () {
    final oneJump = _session(3)..start();
    final smallSteps = _session(3)..start();
    final total = oneJump.opportunities.fold<Duration>(
      Duration.zero,
      (sum, flight) =>
          sum +
          flight.flightDuration +
          BallSession.feedbackDuration +
          BallSession.transitionDuration,
    );

    expect(oneJump.advance(total), isTrue);
    var elapsed = Duration.zero;
    while (elapsed < total) {
      elapsed += const Duration(milliseconds: 17);
      smallSteps.advance(elapsed < total ? elapsed : total);
    }
    expect(oneJump.phase, BallSessionPhase.completed);
    expect(smallSteps.phase, BallSessionPhase.completed);
    expect(oneJump.outcomes, smallSteps.outcomes);
    expect(oneJump.outcomes, everyElement(BallOutcome.miss));
    expect(oneJump.accuratePasses, 0);
    expect(oneJump.bestStreak, 0);
  });

  test('tap at flight end cannot award a hit after a delayed frame', () {
    final session = _session(12)..start();
    final end = session.currentOpportunity.flightDuration;
    expect(session.tap(end), isNull);
    expect(session.outcomes, [BallOutcome.miss]);
    expect(session.phase, BallSessionPhase.feedback);
  });

  test('rapid repeated taps never resolve a return twice', () {
    final session = _session(22)..start();
    final hitAt = _part(session.currentOpportunity.flightDuration, 0.7);
    expect(session.tap(hitAt), BallOutcome.perfect);
    for (var index = 0; index < 100; index++) {
      expect(session.tap(hitAt), isNull);
    }
    expect(session.resolvedCount, 1);
    expect(session.accuratePasses, 1);
    _next(session);
    expect(session.phase, BallSessionPhase.active);
    expect(session.opportunityNumber, 2);
  });

  test('early tap spam cannot shorten the eight-flight session', () {
    final session = _session(33)..start();
    final scheduledEnd = session.opportunities.fold<Duration>(
      Duration.zero,
      (total, flight) =>
          total +
          flight.flightDuration +
          BallSession.feedbackDuration +
          BallSession.transitionDuration,
    );
    for (var turn = 0; turn < BallSession.opportunityCount; turn++) {
      expect(session.phase, BallSessionPhase.active);
      expect(session.tap(session.elapsed), BallOutcome.miss);
      for (var spam = 0; spam < 20; spam++) {
        expect(session.tap(session.elapsed), isNull);
      }
      _next(session);
    }
    expect(session.phase, BallSessionPhase.completed);
    expect(session.elapsed, scheduledEnd);
    expect(session.elapsed, greaterThan(const Duration(seconds: 20)));
    expect(session.accuratePasses, 0);
  });

  test('abort prevents completion and cannot be restarted', () {
    final session = _session(5)..start();
    expect(_tapAtProgress(session, 0.7), BallOutcome.perfect);
    session.abort();
    session.advance(const Duration(hours: 1));
    expect(session.phase, BallSessionPhase.aborted);
    expect(session.canSubmitReward, isFalse);
    expect(session.completion, isNull);
    expect(session.tap(const Duration(hours: 1)), isNull);
    expect(() => session.start(), throwsStateError);
    final replay = _session(5, suffix: '-replay')..start();
    expect(replay.resolvedCount, 0);
    expect(replay.accuratePasses, 0);
    expect(replay.phase, BallSessionPhase.active);
    expect(replay.sessionId, isNot(session.sessionId));
  });

  test('session identity must be explicit and nonempty', () {
    expect(() => BallSession(seed: 1, sessionId: '   '), throwsArgumentError);
  });

  test('elapsed gameplay time is monotonic', () {
    final session = _session(2)..start();
    session.advance(const Duration(milliseconds: 50));
    expect(
      () => session.advance(const Duration(milliseconds: 49)),
      throwsArgumentError,
    );
  });
}
