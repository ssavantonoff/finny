import 'dart:math';

/// Coordinates relative to the playable area, independent of screen size.
final class FrisbeePoint {
  const FrisbeePoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is FrisbeePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

enum FrisbeeOutcome { perfect, good, miss }

enum FrisbeeGestureResult { ignored, invalidShort, invalidDirection, launched }

enum FrisbeeSessionPhase {
  notStarted,
  ready,
  aiming,
  flying,
  feedback,
  completed,
  aborted,
}

/// Proof of six resolved throws. Only [FrisbeeSession] can construct it.
final class FrisbeeCompletion {
  const FrisbeeCompletion._({
    required this.sessionId,
    required this.successfulThrows,
    required this.bestStreak,
  });

  final String sessionId;
  final int successfulThrows;
  final int bestStreak;
  int get totalThrows => FrisbeeSession.throwCount;
}

/// Pure, deterministic rules for a six-throw frisbee game.
///
/// The UI supplies normalized pointer positions and elapsed *gameplay* time.
/// The model has no timer, frame counter, repository, or reward side effect.
/// Its caller aborts an unfinished session when the route or app is left.
final class FrisbeeSession {
  FrisbeeSession({required int seed, required this.sessionId})
    : targets = List.unmodifiable(_makeTargets(seed)) {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Must not be empty.');
    }
  }

  static const throwCount = 6;
  static const launchPoint = FrisbeePoint(0.5, 0.79);
  static const launchHalfWidth = 0.20;
  static const launchHalfHeight = 0.13;
  static const minimumSwipeLength = 0.12;
  static const minimumUpwardComponent = 0.08;
  static const feedbackDuration = Duration(milliseconds: 650);

  /// Forgiving, screen-independent accuracy ellipses around Finny.
  static const perfectRadiusX = 0.075;
  static const perfectRadiusY = 0.07;
  static const goodRadiusX = 0.19;
  static const goodRadiusY = 0.15;

  final String sessionId;
  final List<FrisbeePoint> targets;

  final List<FrisbeeOutcome> _outcomes = [];
  FrisbeeSessionPhase _phase = FrisbeeSessionPhase.notStarted;
  Duration _elapsed = Duration.zero;
  Duration _phaseStartedAt = Duration.zero;
  Duration _flightDuration = Duration.zero;
  int? _pointerId;
  FrisbeePoint? _gestureStart;
  FrisbeePoint? _gesturePosition;
  FrisbeePoint? _landingPoint;
  FrisbeeOutcome? _pendingOutcome;
  FrisbeeCompletion? _completion;
  FrisbeeOutcome? lastOutcome;

  FrisbeeSessionPhase get phase => _phase;
  Duration get elapsed => _elapsed;
  List<FrisbeeOutcome> get outcomes => List.unmodifiable(_outcomes);
  int get resolvedCount => _outcomes.length;

  /// Keep the just-finished throw and its target visible through feedback.
  int get throwNumber => phase == FrisbeeSessionPhase.feedback
      ? resolvedCount
      : min(resolvedCount + 1, throwCount);
  FrisbeePoint get currentTarget => targets[throwNumber - 1];
  FrisbeePoint? get gesturePosition => _gesturePosition;
  FrisbeePoint? get landingPoint => _landingPoint;
  FrisbeeCompletion? get completion => _completion;
  bool get canSubmitReward =>
      phase == FrisbeeSessionPhase.completed && _completion != null;

  int get successfulThrows =>
      _outcomes.where((outcome) => outcome != FrisbeeOutcome.miss).length;

  int get bestStreak {
    var best = 0;
    var current = 0;
    for (final outcome in _outcomes) {
      current = outcome == FrisbeeOutcome.miss ? 0 : current + 1;
      best = max(best, current);
    }
    return best;
  }

  /// The end of the current flight and its feedback. No new gesture is
  /// accepted until this boundary has passed.
  Duration? get nextReadyAt => switch (phase) {
    FrisbeeSessionPhase.flying =>
      _phaseStartedAt + _flightDuration + feedbackDuration,
    FrisbeeSessionPhase.feedback => _phaseStartedAt + feedbackDuration,
    _ => null,
  };

  double get flightProgress {
    if (phase != FrisbeeSessionPhase.flying) return 0;
    return ((_elapsed - _phaseStartedAt).inMicroseconds /
            _flightDuration.inMicroseconds)
        .clamp(0.0, 1.0);
  }

  /// Quadratic arc from the frisbee to its gesture-derived landing point.
  FrisbeePoint? get flightPosition {
    final end = _landingPoint;
    if (phase != FrisbeeSessionPhase.flying || end == null) return null;
    final t = flightProgress;
    final inverse = 1 - t;
    final controlX = (launchPoint.x + end.x) / 2;
    final controlY = min(launchPoint.y, end.y) - 0.17;
    return FrisbeePoint(
      inverse * inverse * launchPoint.x +
          2 * inverse * t * controlX +
          t * t * end.x,
      inverse * inverse * launchPoint.y +
          2 * inverse * t * controlY +
          t * t * end.y,
    );
  }

  void start() {
    if (phase != FrisbeeSessionPhase.notStarted) {
      throw StateError('This frisbee session has already started.');
    }
    _phase = FrisbeeSessionPhase.ready;
  }

  /// Accepts one pointer inside a touch area larger than the visible disc.
  bool beginGesture(int pointerId, FrisbeePoint position) {
    if (phase != FrisbeeSessionPhase.ready || !_inLaunchZone(position)) {
      return false;
    }
    _pointerId = pointerId;
    _gestureStart = position;
    _gesturePosition = position;
    _phase = FrisbeeSessionPhase.aiming;
    return true;
  }

  bool updateGesture(int pointerId, FrisbeePoint position) {
    if (phase != FrisbeeSessionPhase.aiming ||
        _pointerId != pointerId ||
        !position.x.isFinite ||
        !position.y.isFinite) {
      return false;
    }
    _gesturePosition = position;
    return true;
  }

  /// Invalid gestures return to ready without spending a throw.
  FrisbeeGestureResult releaseGesture(
    int pointerId,
    FrisbeePoint position,
    Duration at,
  ) {
    advance(at);
    if (phase != FrisbeeSessionPhase.aiming || _pointerId != pointerId) {
      return FrisbeeGestureResult.ignored;
    }
    if (!position.x.isFinite || !position.y.isFinite) {
      _clearGesture();
      _phase = FrisbeeSessionPhase.ready;
      return FrisbeeGestureResult.invalidDirection;
    }
    final start = _gestureStart!;
    final dx = position.x - start.x;
    final dy = position.y - start.y;
    final length = sqrt(dx * dx + dy * dy);
    _clearGesture();
    if (length < minimumSwipeLength) {
      _phase = FrisbeeSessionPhase.ready;
      return FrisbeeGestureResult.invalidShort;
    }
    final upward = -dy;
    if (upward < minimumUpwardComponent || upward < length * 0.4) {
      _phase = FrisbeeSessionPhase.ready;
      return FrisbeeGestureResult.invalidDirection;
    }

    final target = currentTarget;
    // Gesture slope controls horizontal aim. Strength gently changes the
    // travel extent, but seeded target position never chooses the outcome.
    final travelY = launchPoint.y - target.y;
    final landX = (launchPoint.x + dx / upward * travelY).clamp(0.0, 1.0);
    final landY = (target.y + (0.32 - length.clamp(0.12, 0.55)) * 0.16).clamp(
      0.0,
      1.0,
    );
    _landingPoint = FrisbeePoint(landX, landY);
    _pendingOutcome = _grade(_landingPoint!, target);
    final durationMs = (950 - length.clamp(0.12, 0.55) * 400).round().clamp(
      700,
      950,
    );
    _flightDuration = Duration(milliseconds: durationMs);
    _phaseStartedAt = _elapsed;
    _phase = FrisbeeSessionPhase.flying;
    return FrisbeeGestureResult.launched;
  }

  /// A pointer cancel discards the gesture without ending the game.
  void cancelGesture(int pointerId) {
    if (phase != FrisbeeSessionPhase.aiming || _pointerId != pointerId) return;
    _clearGesture();
    _phase = FrisbeeSessionPhase.ready;
  }

  /// Advances from an elapsed clock, independent of ticker frequency.
  bool advance(Duration nextElapsed) {
    if (nextElapsed < _elapsed) {
      throw ArgumentError.value(
        nextElapsed,
        'nextElapsed',
        'Time cannot reverse.',
      );
    }
    if (phase == FrisbeeSessionPhase.notStarted ||
        phase == FrisbeeSessionPhase.completed ||
        phase == FrisbeeSessionPhase.aborted) {
      return false;
    }
    _elapsed = nextElapsed;
    var changed = false;
    while (true) {
      if (phase == FrisbeeSessionPhase.flying) {
        final flightEnd = _phaseStartedAt + _flightDuration;
        if (_elapsed < flightEnd) break;
        _outcomes.add(_pendingOutcome!);
        lastOutcome = _pendingOutcome;
        _pendingOutcome = null;
        _phase = FrisbeeSessionPhase.feedback;
        _phaseStartedAt = flightEnd;
        changed = true;
      } else if (phase == FrisbeeSessionPhase.feedback) {
        final feedbackEnd = _phaseStartedAt + feedbackDuration;
        if (_elapsed < feedbackEnd) break;
        _phaseStartedAt = feedbackEnd;
        if (resolvedCount == throwCount) {
          _phase = FrisbeeSessionPhase.completed;
          _completion = FrisbeeCompletion._(
            sessionId: sessionId,
            successfulThrows: successfulThrows,
            bestStreak: bestStreak,
          );
        } else {
          _phase = FrisbeeSessionPhase.ready;
          _landingPoint = null;
        }
        changed = true;
      } else {
        break;
      }
    }
    return changed;
  }

  /// A completed run keeps its identity for safe reward retry.
  void abort() {
    if (phase == FrisbeeSessionPhase.completed ||
        phase == FrisbeeSessionPhase.aborted) {
      return;
    }
    _clearGesture();
    _pendingOutcome = null;
    _phase = FrisbeeSessionPhase.aborted;
  }

  void _clearGesture() {
    _pointerId = null;
    _gestureStart = null;
    _gesturePosition = null;
  }

  static bool _inLaunchZone(FrisbeePoint point) =>
      point.x.isFinite &&
      point.y.isFinite &&
      (point.x - launchPoint.x).abs() <= launchHalfWidth &&
      (point.y - launchPoint.y).abs() <= launchHalfHeight;

  static FrisbeeOutcome _grade(FrisbeePoint landing, FrisbeePoint target) {
    final dx = landing.x - target.x;
    final dy = landing.y - target.y;
    final inner =
        dx * dx / (perfectRadiusX * perfectRadiusX) +
        dy * dy / (perfectRadiusY * perfectRadiusY);
    if (inner <= 1) return FrisbeeOutcome.perfect;
    final outer =
        dx * dx / (goodRadiusX * goodRadiusX) +
        dy * dy / (goodRadiusY * goodRadiusY);
    return outer <= 1 ? FrisbeeOutcome.good : FrisbeeOutcome.miss;
  }

  static List<FrisbeePoint> _makeTargets(int seed) {
    final random = Random(seed);
    return List.generate(
      throwCount,
      (_) => FrisbeePoint(0.4 + random.nextDouble() * 0.2, 0.31),
    );
  }
}
