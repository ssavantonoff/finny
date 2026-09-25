import 'dart:math';

/// The outcome of one return. A miss never ends the session early.
enum BallOutcome { perfect, good, miss }

enum BallSessionPhase {
  notStarted,
  active,
  feedback,
  transitioning,
  completed,
  aborted,
}

/// An immutable, seed-generated flight. Coordinates are relative to the play
/// area, so the same session can be rendered at different screen sizes.
final class BallOpportunity {
  const BallOpportunity({
    required this.number,
    required this.flightDuration,
    required this.horizontalOffset,
  });

  /// One-based number shown to the player.
  final int number;
  final Duration flightDuration;

  /// Relative offset from the horizontal center, in the range -0.12..0.12.
  final double horizontalOffset;
}

/// A typed proof that the eight returns in a session have resolved.
/// Construction stays inside [BallSession] so callers cannot label an
/// unfinished session complete by assembling their own result object.
final class BallCompletion {
  const BallCompletion._({
    required this.sessionId,
    required this.accuratePasses,
    required this.bestStreak,
  });

  final String sessionId;
  final int accuratePasses;
  final int bestStreak;
  int get totalPasses => BallSession.opportunityCount;
}

/// Pure time-based rules for one eight-return game of ball with Finny.
///
/// [advance] and [tap] take elapsed gameplay time from the same monotonic clock.
/// The caller may stop that clock while the app is paused, or [abort] the game.
/// This model neither reads nor writes game state, money, or mood.
final class BallSession {
  BallSession({required int seed, required this.sessionId})
    : opportunities = List.unmodifiable(_makeOpportunities(seed)) {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Must not be empty.');
    }
  }

  static const opportunityCount = 8;
  static const feedbackDuration = Duration(milliseconds: 600);
  static const transitionDuration = Duration(milliseconds: 220);
  static const timingCenter = 0.7;
  static const perfectHalfWidth = 0.07;
  static const goodHalfWidth = 0.18;

  final List<BallOpportunity> opportunities;

  /// One stable identity for this gameplay run and every reward retry.
  final String sessionId;
  final List<BallOutcome> _outcomes = [];
  BallSessionPhase _phase = BallSessionPhase.notStarted;
  BallOutcome? lastOutcome;
  Duration _elapsed = Duration.zero;
  Duration _phaseStartedAt = Duration.zero;

  List<BallOutcome> get outcomes => List.unmodifiable(_outcomes);
  BallSessionPhase get phase => _phase;
  int get resolvedCount => _outcomes.length;

  /// One-based; remains at eight on the result screen.
  int get opportunityNumber => min(resolvedCount + 1, opportunityCount);
  BallOpportunity get currentOpportunity =>
      opportunities[opportunityNumber - 1];
  Duration get elapsed => _elapsed;
  bool get canSubmitReward =>
      phase == BallSessionPhase.completed && resolvedCount == opportunityCount;

  /// Earliest elapsed time at which the next return, or completion, begins.
  /// An early tap never shortens the scheduled flight.
  Duration? get nextOpportunityAt => switch (phase) {
    BallSessionPhase.feedback =>
      _phaseStartedAt + feedbackDuration + transitionDuration,
    BallSessionPhase.transitioning => _phaseStartedAt + transitionDuration,
    _ => null,
  };
  BallCompletion? get completion => canSubmitReward
      ? BallCompletion._(
          sessionId: sessionId,
          accuratePasses: accuratePasses,
          bestStreak: bestStreak,
        )
      : null;

  double get progress {
    if (phase != BallSessionPhase.active) return 0;
    final duration = currentOpportunity.flightDuration.inMicroseconds;
    final time = (_elapsed - _phaseStartedAt).inMicroseconds;
    return (time / duration).clamp(0.0, 1.0);
  }

  int get accuratePasses =>
      _outcomes.where((outcome) => outcome != BallOutcome.miss).length;

  int get bestStreak {
    var best = 0;
    var current = 0;
    for (final outcome in _outcomes) {
      current = outcome == BallOutcome.miss ? 0 : current + 1;
      best = max(best, current);
    }
    return best;
  }

  void start() {
    if (phase != BallSessionPhase.notStarted) {
      throw StateError('This ball session has already started.');
    }
    _phase = BallSessionPhase.active;
  }

  /// Returns true when a phase or outcome changed. Position still changes as
  /// elapsed time advances, so a renderer should repaint on each ticker event.
  bool advance(Duration nextElapsed) {
    if (nextElapsed < _elapsed) {
      throw ArgumentError.value(
        nextElapsed,
        'nextElapsed',
        'Time cannot reverse.',
      );
    }
    if (phase == BallSessionPhase.notStarted ||
        phase == BallSessionPhase.completed ||
        phase == BallSessionPhase.aborted) {
      return false;
    }
    _elapsed = nextElapsed;
    var changed = false;
    // Use exact phase boundaries rather than the latest frame timestamp. A
    // delayed frame can resolve several missed returns without extending time.
    while (true) {
      if (phase == BallSessionPhase.active) {
        final flightEnd = _phaseStartedAt + currentOpportunity.flightDuration;
        if (_elapsed < flightEnd) break;
        _resolve(BallOutcome.miss);
        changed = true;
      } else if (phase == BallSessionPhase.feedback) {
        final feedbackEnd = _phaseStartedAt + feedbackDuration;
        if (_elapsed < feedbackEnd) break;
        _phase = BallSessionPhase.transitioning;
        _phaseStartedAt = feedbackEnd;
        changed = true;
      } else if (phase == BallSessionPhase.transitioning) {
        final transitionEnd = _phaseStartedAt + transitionDuration;
        if (_elapsed < transitionEnd) break;
        _phaseStartedAt = transitionEnd;
        _phase = resolvedCount == opportunityCount
            ? BallSessionPhase.completed
            : BallSessionPhase.active;
        changed = true;
      } else {
        break;
      }
    }
    return changed;
  }

  /// Resolves the active return once. Taps in feedback/transition are ignored.
  /// An elapsed flight times out before a late tap can be graded as a hit.
  BallOutcome? tap(Duration at) {
    advance(at);
    if (phase != BallSessionPhase.active) return null;
    final distance = (progress - timingCenter).abs();
    final outcome = distance <= perfectHalfWidth
        ? BallOutcome.perfect
        : distance <= goodHalfWidth
        ? BallOutcome.good
        : BallOutcome.miss;
    _resolve(outcome);
    return outcome;
  }

  void abort() {
    if (phase == BallSessionPhase.completed ||
        phase == BallSessionPhase.aborted) {
      return;
    }
    _phase = BallSessionPhase.aborted;
  }

  void _resolve(BallOutcome outcome) {
    final flightEnd = _phaseStartedAt + currentOpportunity.flightDuration;
    _outcomes.add(outcome);
    lastOutcome = outcome;
    _phase = BallSessionPhase.feedback;
    _phaseStartedAt = flightEnd;
  }

  static List<BallOpportunity> _makeOpportunities(int seed) {
    final random = Random(seed);
    return List.generate(opportunityCount, (index) {
      // The final pass is still comfortably over 1.5 seconds. Seeded jitter
      // changes presentation without moving the forgiving timing windows.
      final baseMs = 2200 - index * 80;
      final jitterMs = random.nextInt(151) - 75;
      final durationMs = max(1550, baseMs + jitterMs);
      final offset = (random.nextDouble() * 0.24) - 0.12;
      return BallOpportunity(
        number: index + 1,
        flightDuration: Duration(milliseconds: durationMs),
        horizontalOffset: offset,
      );
    });
  }
}
