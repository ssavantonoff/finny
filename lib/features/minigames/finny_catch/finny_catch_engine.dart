import 'dart:math';

import 'finny_catch_models.dart';
import 'finny_catch_rules.dart';

class FinnyCatchEngine {
  FinnyCatchEngine({required int seed}) : _random = Random(seed) {
    schedule = List.unmodifiable(_buildSchedule());
  }

  final Random _random;
  late final List<FinnyCatchObject> schedule;
  final Set<int> _resolved = {};
  int score = 0;
  Duration elapsed = Duration.zero;

  int get difficultyPhase => elapsed < const Duration(seconds: 10)
      ? 1
      : elapsed < const Duration(seconds: 20)
      ? 2
      : 3;

  List<FinnyCatchObjectView> get activeObjects => [
    for (final object in schedule)
      if (!_resolved.contains(object.id) &&
          elapsed >= object.spawnAt &&
          object.progressAt(elapsed) <= 1)
        FinnyCatchObjectView(object, object.progressAt(elapsed).clamp(0, 1)),
  ];

  bool isResolved(int id) => _resolved.contains(id);

  void advance(
    Duration nextElapsed, {
    required double finnyX,
    required double catchHalfWidth,
  }) {
    if (nextElapsed < elapsed) {
      throw ArgumentError.value(
        nextElapsed,
        'nextElapsed',
        'Time cannot reverse.',
      );
    }
    elapsed = nextElapsed;
    final caughtX = finnyX.clamp(0.0, 1.0);
    final halfWidth = catchHalfWidth.clamp(0.0, 0.5);
    for (final object in schedule) {
      if (_resolved.contains(object.id) || elapsed < object.spawnAt) continue;
      final progress = object.progressAt(elapsed);
      if (progress >= FinnyCatchRules.catchStartProgress &&
          progress <= 1 &&
          (object.x - caughtX).abs() <= halfWidth) {
        _resolved.add(object.id);
        score = switch (object.type) {
          FinnyCatchObjectType.coin => score + FinnyCatchRules.coinScore,
          FinnyCatchObjectType.sparkle => score + FinnyCatchRules.sparkleScore,
          FinnyCatchObjectType.cloud => max(
            0,
            score - FinnyCatchRules.cloudPenalty,
          ),
        };
      } else if (progress > 1) {
        _resolved.add(object.id);
      }
    }
  }

  List<FinnyCatchObject> _buildSchedule() {
    const phases = [
      _PhaseSpec(0, 7, 1, 1, 2600, 1000),
      _PhaseSpec(10000, 7, 1, 2, 2400, 950),
      _PhaseSpec(20000, 7, 1, 3, 2200, 750),
    ];
    final objects = <FinnyCatchObject>[];
    FinnyCatchObjectType? previousType;
    int? previousLane;
    int sameLaneCount = 0;
    Duration? previousArrival;

    for (var phaseIndex = 0; phaseIndex < phases.length; phaseIndex++) {
      final phase = phases[phaseIndex];
      final types = _typesForPhase(phase, previousType, first: phaseIndex == 0);
      for (var index = 0; index < types.length; index++) {
        final spawnAt = Duration(
          milliseconds: phase.startMs + index * phase.intervalMs,
        );
        final fallDuration = Duration(milliseconds: phase.fallMs);
        final arrival = spawnAt + fallDuration;
        if (previousArrival != null &&
            arrival - previousArrival < FinnyCatchRules.minCatchArrivalGap) {
          throw StateError('Catch arrivals overlap.');
        }
        final candidates = List<int>.generate(
          FinnyCatchRules.laneCount,
          (i) => i,
        )..shuffle(_random);
        final lane = candidates.firstWhere((candidate) {
          if (candidate == previousLane && sameLaneCount >= 2) return false;
          if (previousLane != null &&
              arrival - previousArrival! < const Duration(milliseconds: 1100) &&
              (candidate - previousLane).abs() > 2) {
            return false;
          }
          return true;
        });
        sameLaneCount = lane == previousLane ? sameLaneCount + 1 : 1;
        previousLane = lane;
        previousArrival = arrival;
        previousType = types[index];
        objects.add(
          FinnyCatchObject(
            id: objects.length,
            type: types[index],
            lane: lane,
            spawnAt: spawnAt,
            fallDuration: fallDuration,
          ),
        );
      }
    }
    return objects;
  }

  List<FinnyCatchObjectType> _typesForPhase(
    _PhaseSpec phase,
    FinnyCatchObjectType? previous, {
    required bool first,
  }) {
    final counts = <FinnyCatchObjectType, int>{
      FinnyCatchObjectType.coin: phase.coins,
      FinnyCatchObjectType.sparkle: phase.sparkles,
      FinnyCatchObjectType.cloud: phase.clouds,
    };
    List<FinnyCatchObjectType>? choose(
      List<FinnyCatchObjectType> chosen,
      FinnyCatchObjectType? last,
    ) {
      if (chosen.length == phase.total) return chosen;
      final options = FinnyCatchObjectType.values.toList()..shuffle(_random);
      for (final type in options) {
        if (counts[type] == 0 ||
            (first && chosen.length < 3 && type != FinnyCatchObjectType.coin) ||
            (last == FinnyCatchObjectType.cloud &&
                type == FinnyCatchObjectType.cloud)) {
          continue;
        }
        counts[type] = counts[type]! - 1;
        final result = choose([...chosen, type], type);
        if (result != null) return result;
        counts[type] = counts[type]! + 1;
      }
      return null;
    }

    return choose([], previous) ?? (throw StateError('No fair type sequence.'));
  }
}

class _PhaseSpec {
  const _PhaseSpec(
    this.startMs,
    this.coins,
    this.sparkles,
    this.clouds,
    this.fallMs,
    this.intervalMs,
  );
  final int startMs;
  final int coins;
  final int sparkles;
  final int clouds;
  final int fallMs;
  final int intervalMs;
  int get total => coins + sparkles + clouds;
}
