import 'dart:math';

enum CarOutcome { perfect, good, miss }

enum CarSessionPhase { notStarted, driving, feedback, completed, aborted }

/// One section of a track in coordinates normalized to the playable width.
/// Each bend starts and ends on the center line so adjacent sections join.
final class CarTrackSection {
  const CarTrackSection({required this.bend, this.halfWidth = 0.245})
    : assert(bend >= -0.24 && bend <= 0.24),
      assert(halfWidth >= 0.21 && halfWidth <= 0.25);

  final double bend;
  final double halfWidth;

  double centerAt(double progress) =>
      0.5 + bend * sin(pi * progress.clamp(0.0, 1.0));

  double leftAt(double progress) => centerAt(progress) - halfWidth;
  double rightAt(double progress) => centerAt(progress) + halfWidth;

  @override
  bool operator ==(Object other) =>
      other is CarTrackSection &&
      other.bend == bend &&
      other.halfWidth == halfWidth;

  @override
  int get hashCode => Object.hash(bend, halfWidth);
}

/// Proof of six resolved sections. Only [CarSession] can construct it.
final class CarCompletion {
  const CarCompletion._({
    required this.sessionId,
    required this.successfulSections,
    required this.bestStreak,
  });

  final String sessionId;
  final int successfulSections;
  final int bestStreak;
  int get totalSections => CarSession.sectionCount;
}

/// Pure rules for a six-section, overhead steering game.
///
/// The caller supplies normalized pointer X and elapsed gameplay time from
/// one monotonic clock. No widget, repository, random outcome, or reward side
/// effect lives here. The caller aborts on route or app interruption.
final class CarSession {
  CarSession({
    required int seed,
    required this.sessionId,
    List<CarTrackSection>? sections,
  }) : sections = List.unmodifiable(sections ?? _makeSections(seed)) {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Must not be empty.');
    }
    if (this.sections.length != sectionCount) {
      throw ArgumentError.value(
        this.sections.length,
        'sections',
        'Exactly six track sections are required.',
      );
    }
  }

  static const sectionCount = 6;
  static const sectionDuration = Duration(milliseconds: 2400);
  static const feedbackDuration = Duration(milliseconds: 650);
  static const simulationStep = Duration(milliseconds: 10);
  // Visible car is about 0.19 of the canvas wide. Include the rail's inward
  // stroke so a visually touching car is graded as a border contact.
  static const carHalfWidth = 0.12;
  static const steeringSpeed = 0.68; // Normalized playable widths per second.
  static const perfectAverageError = 0.065;

  final String sessionId;
  final List<CarTrackSection> sections;

  final List<CarOutcome> _outcomes = [];
  CarSessionPhase _phase = CarSessionPhase.notStarted;
  Duration _elapsed = Duration.zero;
  Duration _phaseStartedAt = Duration.zero;
  Duration _nextSampleAt = simulationStep;
  double _carX = 0.5;
  double _desiredX = 0.5;
  double _errorSum = 0;
  int _sampleCount = 0;
  bool _touchedBorder = false;
  int _successfulSections = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int? _activePointer;
  double _pointerStartX = 0.5;
  double _carAtPointerStart = 0.5;
  CarCompletion? _completion;
  CarOutcome? lastOutcome;

  CarSessionPhase get phase => _phase;
  Duration get elapsed => _elapsed;
  double get carX => _carX;
  List<CarOutcome> get outcomes => List.unmodifiable(_outcomes);
  int get resolvedSections => _outcomes.length;
  int get successfulSections => _successfulSections;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  CarCompletion? get completion => _completion;
  bool get canSubmitReward =>
      phase == CarSessionPhase.completed && _completion != null;

  /// During feedback, keep the just-resolved section visible.
  int get sectionNumber => switch (phase) {
    CarSessionPhase.feedback ||
    CarSessionPhase.completed => max(1, min(resolvedSections, sectionCount)),
    _ => min(resolvedSections + 1, sectionCount),
  };

  CarTrackSection get currentSection => sections[sectionNumber - 1];

  double get sectionProgress => switch (phase) {
    CarSessionPhase.driving =>
      ((_elapsed - _phaseStartedAt).inMicroseconds /
              sectionDuration.inMicroseconds)
          .clamp(0.0, 1.0),
    CarSessionPhase.feedback || CarSessionPhase.completed => 1.0,
    _ => 0.0,
  };

  void start() {
    if (phase != CarSessionPhase.notStarted) {
      throw StateError('This car session has already started.');
    }
    _phase = CarSessionPhase.driving;
  }

  /// A drag is relative to the car's position when the finger went down.
  /// Beginning a drag away from the car never teleports it under the finger.
  bool beginSteering(int pointerId, double normalizedX, Duration at) {
    advance(at);
    if (!_acceptsInput || _activePointer != null || !normalizedX.isFinite) {
      return false;
    }
    _activePointer = pointerId;
    _pointerStartX = normalizedX.clamp(0.0, 1.0);
    _carAtPointerStart = _carX;
    _desiredX = _carX;
    return true;
  }

  bool updateSteering(int pointerId, double normalizedX, Duration at) {
    advance(at);
    if (!_acceptsInput ||
        _activePointer != pointerId ||
        !normalizedX.isFinite) {
      return false;
    }
    _desiredX =
        (_carAtPointerStart + normalizedX.clamp(0.0, 1.0) - _pointerStartX)
            .clamp(carHalfWidth, 1 - carHalfWidth);
    return true;
  }

  bool endSteering(int pointerId, Duration at) {
    advance(at);
    if (_activePointer != pointerId) return false;
    _releasePointer();
    return true;
  }

  bool cancelSteering(int pointerId, Duration at) => endSteering(pointerId, at);

  bool get _acceptsInput =>
      phase == CarSessionPhase.driving || phase == CarSessionPhase.feedback;

  void _releasePointer() {
    _activePointer = null;
    _desiredX = _carX;
  }

  /// Returns whether a section or phase changed. Position also changes as
  /// time advances, so the UI should repaint on every animation tick.
  bool advance(Duration nextElapsed) {
    if (nextElapsed < _elapsed) {
      throw ArgumentError.value(
        nextElapsed,
        'nextElapsed',
        'Time cannot reverse.',
      );
    }
    if (phase == CarSessionPhase.notStarted ||
        phase == CarSessionPhase.completed ||
        phase == CarSessionPhase.aborted) {
      return false;
    }

    var cursor = _elapsed;
    var changed = false;
    while (true) {
      if (phase == CarSessionPhase.driving) {
        final sectionEnd = _phaseStartedAt + sectionDuration;
        final until = nextElapsed < sectionEnd ? nextElapsed : sectionEnd;
        _driveFromTo(cursor, until);
        cursor = until;
        if (cursor < sectionEnd) break;
        _resolveSection();
        _phaseStartedAt = sectionEnd;
        _phase = CarSessionPhase.feedback;
        changed = true;
      } else if (phase == CarSessionPhase.feedback) {
        final feedbackEnd = _phaseStartedAt + feedbackDuration;
        cursor = nextElapsed < feedbackEnd ? nextElapsed : feedbackEnd;
        if (cursor < feedbackEnd) break;
        _phaseStartedAt = feedbackEnd;
        if (resolvedSections == sectionCount) {
          _phase = CarSessionPhase.completed;
          _releasePointer();
          _completion = CarCompletion._(
            sessionId: sessionId,
            successfulSections: successfulSections,
            bestStreak: bestStreak,
          );
        } else {
          _phase = CarSessionPhase.driving;
          _nextSampleAt = feedbackEnd + simulationStep;
          _errorSum = 0;
          _sampleCount = 0;
          _touchedBorder = false;
        }
        changed = true;
      } else {
        break;
      }
      if (cursor >= nextElapsed) break;
    }
    _elapsed = nextElapsed;
    return changed;
  }

  void _driveFromTo(Duration from, Duration to) {
    var cursor = from;
    while (_nextSampleAt <= to) {
      _moveFor(_nextSampleAt - cursor);
      cursor = _nextSampleAt;
      _sampleAt(cursor);
      _nextSampleAt += simulationStep;
    }
    _moveFor(to - cursor);
  }

  void _moveFor(Duration interval) {
    final maxMovement =
        steeringSpeed *
        interval.inMicroseconds /
        Duration.microsecondsPerSecond;
    final difference = _desiredX - _carX;
    _carX = (_carX + difference.clamp(-maxMovement, maxMovement)).clamp(
      carHalfWidth,
      1 - carHalfWidth,
    );
  }

  void _sampleAt(Duration at) {
    final progress =
        (at - _phaseStartedAt).inMicroseconds / sectionDuration.inMicroseconds;
    final section = currentSection;
    final distance = (_carX - section.centerAt(progress)).abs();
    _errorSum += distance;
    _sampleCount++;
    if (distance >= section.halfWidth - carHalfWidth) {
      _touchedBorder = true;
    }
  }

  void _resolveSection() {
    assert(_sampleCount > 0);
    final outcome = classifySection(
      touchedBorder: _touchedBorder,
      averageCenterError: _errorSum / _sampleCount,
    );
    _outcomes.add(outcome);
    lastOutcome = outcome;
    if (outcome == CarOutcome.miss) {
      _currentStreak = 0;
    } else {
      _successfulSections++;
      _currentStreak++;
      _bestStreak = max(_bestStreak, _currentStreak);
    }
  }

  /// Both thresholds are relative to the playable width, never device pixels.
  static CarOutcome classifySection({
    required bool touchedBorder,
    required double averageCenterError,
  }) {
    if (touchedBorder) return CarOutcome.miss;
    return averageCenterError <= perfectAverageError
        ? CarOutcome.perfect
        : CarOutcome.good;
  }

  /// An interrupted run never creates a completion proof.
  void abort() {
    if (phase == CarSessionPhase.completed ||
        phase == CarSessionPhase.aborted) {
      return;
    }
    _releasePointer();
    _phase = CarSessionPhase.aborted;
  }

  static List<CarTrackSection> _makeSections(int seed) {
    final random = Random(seed);
    return List.generate(sectionCount, (_) {
      final magnitude = 0.16 + random.nextDouble() * 0.065;
      return CarTrackSection(bend: random.nextBool() ? magnitude : -magnitude);
    });
  }
}
