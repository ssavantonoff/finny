import 'package:finny/features/minigames/car/car_session.dart';
import 'package:flutter_test/flutter_test.dart';

List<CarTrackSection> get _straightTrack => List.generate(
  CarSession.sectionCount,
  (_) => const CarTrackSection(bend: 0),
);

CarSession _session(int seed, {String suffix = '', bool straight = false}) =>
    CarSession(
      seed: seed,
      sessionId: 'car-$seed$suffix',
      sections: straight ? _straightTrack : null,
    )..start();

Duration _driveEnd(int sectionNumber) =>
    CarSession.sectionDuration * sectionNumber +
    CarSession.feedbackDuration * (sectionNumber - 1);

Duration _feedbackEnd(int sectionNumber) =>
    (CarSession.sectionDuration + CarSession.feedbackDuration) * sectionNumber;

void _runStraightSection(
  CarSession session, {
  required double targetX,
  bool returnToCenter = false,
}) {
  final number = session.sectionNumber;
  final start = session.elapsed;
  final startingX = session.carX;
  expect(session.beginSteering(1, 0.5, start), isTrue);
  expect(session.updateSteering(1, 0.5 + targetX - startingX, start), isTrue);
  if (returnToCenter) {
    final correctionAt = start + const Duration(milliseconds: 750);
    session.advance(correctionAt);
    expect(
      session.updateSteering(1, 0.5 + 0.5 - startingX, correctionAt),
      isTrue,
    );
  }
  session.advance(_driveEnd(number));
  expect(session.phase, CarSessionPhase.feedback);
  expect(session.sectionNumber, number);
  expect(session.sectionProgress, 1);
  session.advance(_feedbackEnd(number));
  session.endSteering(1, session.elapsed);
}

void _pumpTo(CarSession session, Duration end, Duration step) {
  while (session.elapsed < end) {
    final next = session.elapsed + step;
    session.advance(next < end ? next : end);
  }
}

void main() {
  test('fresh run has six seeded, normalized sections and no completion', () {
    final beforeStart = CarSession(seed: 42, sessionId: 'before-start');
    expect(beforeStart.phase, CarSessionPhase.notStarted);
    expect(beforeStart.completion, isNull);
    beforeStart.start();
    expect(beforeStart.phase, CarSessionPhase.driving);
    expect(beforeStart.resolvedSections, 0);
    expect(beforeStart.sectionNumber, 1);
    expect(beforeStart.sectionProgress, 0);
    expect(beforeStart.carX, 0.5);
    expect(beforeStart.successfulSections, 0);
    expect(beforeStart.currentStreak, 0);
    expect(beforeStart.bestStreak, 0);
    expect(beforeStart.canSubmitReward, isFalse);
    expect(beforeStart.sections, hasLength(CarSession.sectionCount));
    for (final section in beforeStart.sections) {
      for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(section.leftAt(progress), inInclusiveRange(0.0, 1.0));
        expect(section.rightAt(progress), inInclusiveRange(0.0, 1.0));
        expect(
          section.rightAt(progress),
          greaterThan(section.leftAt(progress)),
        );
      }
      expect(section.centerAt(0), 0.5);
      expect(section.centerAt(1), closeTo(0.5, 1e-12));
    }
    expect(() => beforeStart.start(), throwsStateError);
  });

  test('seed fixes six varied shapes and other seeds vary the route', () {
    expect(_session(17).sections, _session(17, suffix: '-again').sections);
    expect(_session(17).sections, isNot(_session(18).sections));
    final sections = _session(17).sections;
    expect(sections.first.shape, CarTrackShape.leadIn);
    expect(sections.map((section) => section.shape).toSet(), hasLength(6));
    expect(
      _session(18).sections.map((section) => section.shape).toList(),
      isNot(sections.map((section) => section.shape).toList()),
    );
    expect(
      () => CarSession(seed: 1, sessionId: 'invalid', sections: []),
      throwsArgumentError,
    );
    expect(() => CarSession(seed: 1, sessionId: '   '), throwsArgumentError);
  });

  test('first section has a safe straight lead-in before a gentle bend', () {
    for (var seed = 0; seed < 40; seed++) {
      final session = _session(seed);
      final first = session.sections.first;
      expect(first.centerAt(0), 0.5);
      expect(first.centerAt(0.28), 0.5);
      expect((first.centerAt(0.4) - 0.5).abs(), lessThan(0.04));
      expect((first.centerAt(0.68) - 0.5).abs(), greaterThan(0.15));
      session.advance(const Duration(milliseconds: 950));
      expect(session.carX, 0.5);
      expect(session.phase, CarSessionPhase.driving);
      expect(
        (first.centerAt(session.sectionProgress) - session.carX).abs(),
        lessThan(first.halfWidth - CarSession.carHalfWidth),
      );
      expect(
        (first.centerAt(0.29) - first.centerAt(0.28)).abs(),
        lessThan(0.001),
      );
    }
  });

  test('generated center and borders stay in bounds with smooth joins', () {
    const epsilon = 0.0001;
    for (var seed = 0; seed < 80; seed++) {
      final sections = _session(seed).sections;
      for (final section in sections) {
        for (var sample = 0; sample <= 100; sample++) {
          final progress = sample / 100;
          final center = section.centerAt(progress);
          final left = section.leftAt(progress);
          final right = section.rightAt(progress);
          expect(center, inInclusiveRange(0.30, 0.70));
          expect(left, inInclusiveRange(0.0, 1.0));
          expect(right, inInclusiveRange(0.0, 1.0));
          expect((left + right) / 2, closeTo(center, 1e-12));
        }
      }
      for (var index = 0; index < sections.length - 1; index++) {
        final current = sections[index];
        final next = sections[index + 1];
        expect(current.centerAt(1), closeTo(next.centerAt(0), 1e-12));
        expect(current.leftAt(1), closeTo(next.leftAt(0), 1e-12));
        expect(current.rightAt(1), closeTo(next.rightAt(0), 1e-12));
        final outgoingSlope =
            (current.centerAt(1) - current.centerAt(1 - epsilon)) / epsilon;
        final incomingSlope =
            (next.centerAt(epsilon) - next.centerAt(0)) / epsilon;
        expect((outgoingSlope - incomingSlope).abs(), lessThan(0.01));
      }
    }
  });

  test('generated routes can be followed at the existing steering speed', () {
    for (var seed = 0; seed < 40; seed++) {
      final session = _session(seed);
      for (var number = 1; number <= CarSession.sectionCount; number++) {
        final section = session.currentSection;
        final start = session.elapsed;
        final startingX = session.carX;
        expect(session.beginSteering(1, 0.5, start), isTrue);
        for (var sample = 1; sample < 240; sample++) {
          final at = start + Duration(milliseconds: sample * 10);
          final center = section.centerAt(sample / 240);
          expect(
            session.updateSteering(1, 0.5 + center - startingX, at),
            isTrue,
          );
        }
        session.advance(_driveEnd(number));
        expect(session.outcomes.last, isNot(CarOutcome.miss));
        session.advance(_feedbackEnd(number));
        session.endSteering(1, session.elapsed);
      }
      expect(session.phase, CarSessionPhase.completed);
      expect(session.successfulSections, CarSession.sectionCount);
    }
  });

  test('normalized grading is Perfect, Good, or Miss without random input', () {
    expect(
      CarSession.classifySection(touchedBorder: false, averageCenterError: 0),
      CarOutcome.perfect,
    );
    expect(
      CarSession.classifySection(
        touchedBorder: false,
        averageCenterError: CarSession.perfectAverageError,
      ),
      CarOutcome.perfect,
    );
    expect(
      CarSession.classifySection(
        touchedBorder: false,
        averageCenterError: CarSession.perfectAverageError + 0.01,
      ),
      CarOutcome.good,
    );
    expect(
      CarSession.classifySection(touchedBorder: true, averageCenterError: 0),
      CarOutcome.miss,
    );
    final seedOne = _session(1, straight: true);
    final seedTwo = _session(200, straight: true);
    _runStraightSection(seedOne, targetX: 0.60);
    _runStraightSection(seedTwo, targetX: 0.60);
    expect(seedOne.outcomes, seedTwo.outcomes);
    expect(seedOne.outcomes, [CarOutcome.good]);
  });

  test('a centered drive is Perfect and increases success and streak', () {
    final session = _session(2, straight: true);
    _runStraightSection(session, targetX: 0.5);
    expect(session.outcomes, [CarOutcome.perfect]);
    expect(session.resolvedSections, 1);
    expect(session.successfulSections, 1);
    expect(session.currentStreak, 1);
    expect(session.bestStreak, 1);
    expect(session.completion, isNull);
    expect(session.canSubmitReward, isFalse);
  });

  test('an off-center drive is Good and still counts as success', () {
    final session = _session(3, straight: true);
    _runStraightSection(session, targetX: 0.60);
    expect(session.outcomes, [CarOutcome.good]);
    expect(session.successfulSections, 1);
    expect(session.currentStreak, 1);
  });

  test('contact with either border is Miss, but play continues', () {
    for (final targetX in [0.045, 0.955]) {
      final session = _session(4, straight: true, suffix: '-$targetX');
      _runStraightSection(session, targetX: targetX, returnToCenter: true);
      expect(session.outcomes, [CarOutcome.miss]);
      expect(session.successfulSections, 0);
      expect(session.currentStreak, 0);
      expect(session.bestStreak, 0);
      expect(session.phase, CarSessionPhase.driving);
      expect(session.sectionNumber, 2);
      expect(session.completion, isNull);
    }
  });

  test('six outcomes calculate success and best streak; complete once', () {
    final session = _session(5, straight: true);
    _runStraightSection(session, targetX: 0.5);
    _runStraightSection(session, targetX: 0.60);
    _runStraightSection(session, targetX: 0.955, returnToCenter: true);
    expect(session.outcomes, [
      CarOutcome.perfect,
      CarOutcome.good,
      CarOutcome.miss,
    ]);
    expect(session.currentStreak, 0);
    expect(session.bestStreak, 2);
    expect(session.completion, isNull);
    _runStraightSection(session, targetX: 0.60);
    _runStraightSection(session, targetX: 0.5);
    expect(session.currentStreak, 2);
    expect(session.bestStreak, 2);
    expect(session.completion, isNull);
    _runStraightSection(session, targetX: 0.60);
    expect(session.phase, CarSessionPhase.completed);
    expect(session.resolvedSections, 6);
    expect(session.successfulSections, 5);
    expect(session.currentStreak, 3);
    expect(session.bestStreak, 3);
    expect(session.canSubmitReward, isTrue);
    final completion = session.completion!;
    expect(completion.sessionId, session.sessionId);
    expect(completion.totalSections, 6);
    expect(completion.successfulSections, 5);
    expect(completion.bestStreak, 3);
    expect(session.sectionNumber, 6);
    session.advance(session.elapsed + const Duration(days: 1));
    session.abort();
    expect(identical(session.completion, completion), isTrue);
    expect(session.resolvedSections, 6);
    expect(session.beginSteering(2, 0.5, session.elapsed), isFalse);
  });

  test('a repeated boundary callback cannot resolve a section twice', () {
    final session = _session(6, straight: true);
    session.advance(CarSession.sectionDuration);
    expect(session.phase, CarSessionPhase.feedback);
    expect(session.resolvedSections, 1);
    session.advance(CarSession.sectionDuration);
    session.advance(CarSession.sectionDuration);
    expect(session.resolvedSections, 1);
    session.advance(_feedbackEnd(1));
    expect(session.resolvedSections, 1);
    expect(session.sectionNumber, 2);
  });

  test('one active pointer, cancellation, and bounded steering are safe', () {
    final session = _session(7, straight: true);
    expect(session.beginSteering(1, double.nan, Duration.zero), isFalse);
    expect(session.beginSteering(1, 0.1, Duration.zero), isTrue);
    expect(session.carX, 0.5); // Touching elsewhere never teleports the car.
    expect(session.beginSteering(2, 0.9, Duration.zero), isFalse);
    expect(session.updateSteering(2, 1, Duration.zero), isFalse);
    expect(session.updateSteering(1, double.infinity, Duration.zero), isFalse);
    expect(session.updateSteering(1, 1, Duration.zero), isTrue);
    session.advance(const Duration(milliseconds: 100));
    expect(session.carX, closeTo(0.5 + CarSession.steeringSpeed * 0.1, 1e-9));
    expect(session.carX, lessThan(0.6));
    expect(session.cancelSteering(2, session.elapsed), isFalse);
    expect(session.cancelSteering(1, session.elapsed), isTrue);
    final stoppedX = session.carX;
    session.advance(const Duration(milliseconds: 300));
    expect(session.carX, closeTo(stoppedX, 1e-12));
    expect(session.beginSteering(3, 0.5, session.elapsed), isTrue);
    expect(session.updateSteering(3, -10, session.elapsed), isTrue);
    session.advance(CarSession.sectionDuration);
    expect(
      session.carX,
      inInclusiveRange(CarSession.carHalfWidth, 1 - CarSession.carHalfWidth),
    );
  });

  test(
    'large and tiny animation advances resolve identical input timelines',
    () {
      final large = _session(31);
      final small = _session(31, suffix: '-small');
      for (final session in [large, small]) {
        expect(session.beginSteering(1, 0.5, Duration.zero), isTrue);
        expect(session.updateSteering(1, 0.96, Duration.zero), isTrue);
      }
      const firstChange = Duration(milliseconds: 503);
      small.advance(const Duration(milliseconds: 17));
      _pumpTo(small, firstChange, const Duration(milliseconds: 7));
      large.advance(firstChange);
      expect(large.carX, closeTo(small.carX, 1e-12));
      for (final session in [large, small]) {
        expect(session.updateSteering(1, 0.43, firstChange), isTrue);
      }
      const release = Duration(milliseconds: 1101);
      _pumpTo(small, release, const Duration(milliseconds: 13));
      large.advance(release);
      expect(large.carX, closeTo(small.carX, 1e-12));
      for (final session in [large, small]) {
        expect(session.endSteering(1, release), isTrue);
      }
      final finish = _feedbackEnd(6);
      large.advance(finish);
      _pumpTo(small, finish, const Duration(milliseconds: 19));
      expect(large.phase, CarSessionPhase.completed);
      expect(small.phase, CarSessionPhase.completed);
      expect(large.outcomes, small.outcomes);
      expect(large.successfulSections, small.successfulSections);
      expect(large.bestStreak, small.bestStreak);
      expect(large.carX, closeTo(small.carX, 1e-12));
    },
  );

  test('an aborted session has no completion and replay is a new run', () {
    final session = _session(8, straight: true);
    session.advance(const Duration(milliseconds: 1500));
    session.abort();
    session.advance(const Duration(hours: 1));
    expect(session.phase, CarSessionPhase.aborted);
    expect(session.resolvedSections, 0);
    expect(session.completion, isNull);
    expect(session.canSubmitReward, isFalse);
    expect(() => session.start(), throwsStateError);
    final replay = _session(8, straight: true, suffix: '-replay');
    expect(replay.sessionId, isNot(session.sessionId));
    expect(replay.resolvedSections, 0);
    expect(replay.phase, CarSessionPhase.driving);
  });

  test('elapsed time cannot move backward', () {
    final session = _session(9);
    session.advance(const Duration(milliseconds: 50));
    expect(
      () => session.advance(const Duration(milliseconds: 49)),
      throwsArgumentError,
    );
  });
}
