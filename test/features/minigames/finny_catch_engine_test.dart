import 'package:finny/features/minigames/finny_catch/finny_catch_engine.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Duration catchAt(FinnyCatchObject object) =>
    object.spawnAt +
    Duration(microseconds: object.fallDuration.inMicroseconds * 9 ~/ 10);

void main() {
  test('reward formula has the agreed base and cap', () {
    expect(FinnyCatchRules.rewardForScore(0), 10);
    expect(FinnyCatchRules.rewardForScore(5), 15);
    expect(FinnyCatchRules.rewardForScore(23), 33);
    expect(FinnyCatchRules.rewardForScore(30), 40);
    expect(FinnyCatchRules.rewardForScore(100), 40);
  });

  test('seeded schedule has exact composition and fair arrivals', () {
    for (final seed in [0, 1, 42, 12345, 987654]) {
      final schedule = FinnyCatchEngine(seed: seed).schedule;
      expect(schedule.length, 30);
      expect(
        schedule.where((o) => o.type == FinnyCatchObjectType.coin).length,
        21,
      );
      expect(
        schedule.where((o) => o.type == FinnyCatchObjectType.sparkle).length,
        3,
      );
      expect(
        schedule.where((o) => o.type == FinnyCatchObjectType.cloud).length,
        6,
      );
      for (final (start, end, clouds) in [(0, 9, 1), (9, 19, 2), (19, 30, 3)]) {
        final phase = schedule.sublist(start, end);
        expect(
          phase.where((o) => o.type == FinnyCatchObjectType.coin).length,
          7,
        );
        expect(
          phase.where((o) => o.type == FinnyCatchObjectType.sparkle).length,
          1,
        );
        expect(
          phase.where((o) => o.type == FinnyCatchObjectType.cloud).length,
          clouds,
        );
      }
      expect(
        schedule.take(3).every((o) => o.type == FinnyCatchObjectType.coin),
        isTrue,
      );
      for (var i = 0; i < schedule.length; i++) {
        final object = schedule[i];
        expect(object.lane, inInclusiveRange(0, 4));
        expect(object.x, inExclusiveRange(0, 1));
        expect(object.arrivalAt, lessThan(FinnyCatchRules.roundDuration));
        if (i == 0) continue;
        final previous = schedule[i - 1];
        expect(
          object.arrivalAt - previous.arrivalAt,
          greaterThanOrEqualTo(FinnyCatchRules.minCatchArrivalGap),
        );
        expect(
          previous.type == FinnyCatchObjectType.cloud &&
              object.type == FinnyCatchObjectType.cloud,
          isFalse,
        );
        if (object.arrivalAt - previous.arrivalAt <
            const Duration(milliseconds: 1100)) {
          expect((object.lane - previous.lane).abs(), lessThanOrEqualTo(2));
        }
        if (i >= 2) {
          expect(
            object.lane == previous.lane &&
                previous.lane == schedule[i - 2].lane,
            isFalse,
          );
        }
      }
      expect(
        FinnyCatchEngine(seed: seed).schedule.map((o) => o.lane),
        schedule.map((o) => o.lane),
      );
    }
  });

  test('coin and sparkle score once; cloud subtracts but never below zero', () {
    final engine = FinnyCatchEngine(seed: 42);
    final firstCoin = engine.schedule.first;
    engine.advance(
      catchAt(firstCoin),
      finnyX: firstCoin.x,
      catchHalfWidth: 0.01,
    );
    expect(engine.score, 1);
    engine.advance(
      catchAt(firstCoin),
      finnyX: firstCoin.x,
      catchHalfWidth: 0.01,
    );
    expect(engine.score, 1);
    final sparkle = engine.schedule.firstWhere(
      (o) => o.type == FinnyCatchObjectType.sparkle,
    );
    engine.advance(catchAt(sparkle), finnyX: sparkle.x, catchHalfWidth: 0.01);
    expect(engine.score, 4);
    final cloud = engine.schedule.firstWhere(
      (o) =>
          o.type == FinnyCatchObjectType.cloud && o.spawnAt > sparkle.spawnAt,
    );
    engine.advance(catchAt(cloud), finnyX: cloud.x, catchHalfWidth: 0.01);
    expect(engine.score, 2);
    expect(engine.isResolved(cloud.id), isTrue);

    final empty = FinnyCatchEngine(seed: 42);
    final firstCloud = empty.schedule.firstWhere(
      (o) => o.type == FinnyCatchObjectType.cloud,
    );
    empty.advance(
      catchAt(firstCloud),
      finnyX: firstCloud.x,
      catchHalfWidth: 0.01,
    );
    expect(empty.score, 0);
  });

  test('missing good objects and dodging clouds do not change score', () {
    final engine = FinnyCatchEngine(seed: 1);
    for (final object in engine.schedule) {
      engine.advance(
        object.arrivalAt + const Duration(microseconds: 1),
        finnyX: object.x < 0.5 ? 1 : 0,
        catchHalfWidth: 0,
      );
    }
    expect(engine.score, 0);
    expect(engine.activeObjects, isEmpty);
  });

  test('outside catch zone does not resolve until arrival passes', () {
    final engine = FinnyCatchEngine(seed: 2);
    final object = engine.schedule.first;
    engine.advance(catchAt(object), finnyX: 1, catchHalfWidth: 0.01);
    expect(engine.isResolved(object.id), isFalse);
    engine.advance(
      object.arrivalAt + const Duration(microseconds: 1),
      finnyX: 1,
      catchHalfWidth: 0.01,
    );
    expect(engine.isResolved(object.id), isTrue);
    expect(engine.score, 0);
  });
}
