import 'dart:async';

import 'package:finny/models/game_period.dart';
import 'package:finny/repositories/game_repository.dart';

class ActiveGameplayTracker {
  ActiveGameplayTracker(
    this._gameRepository,
    this._activeProfileId, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final GameRepository _gameRepository;
  final int? Function() _activeProfileId;
  final DateTime Function() _now;

  DateTime? _segmentStartedAt;
  int? _segmentProfileId;
  Future<void> _pending = Future.value();

  void resume() {
    if (_segmentStartedAt != null) return;
    _segmentStartedAt = _now();
    _segmentProfileId = _activeProfileId();
  }

  Future<void> flush() {
    final startedAt = _segmentStartedAt;
    if (startedAt == null) return _pending;
    final now = _now();
    final profileId = _segmentProfileId;
    _segmentStartedAt = now;
    _segmentProfileId = _activeProfileId();
    return _enqueue(now.difference(startedAt), profileId);
  }

  Future<void> pause() {
    final startedAt = _segmentStartedAt;
    final profileId = _segmentProfileId;
    _segmentStartedAt = null;
    _segmentProfileId = null;
    if (startedAt == null) return _pending;
    return _enqueue(_now().difference(startedAt), profileId);
  }

  Future<void> _enqueue(Duration elapsed, int? profileId) {
    if (elapsed <= Duration.zero || profileId == null) return _pending;
    _pending = _pending
        .then((_) async {
          final period = await _gameRepository.getCurrentPeriod(profileId);
          if (period?.id == null ||
              period!.status != GamePeriodStatus.active &&
                  period.status != GamePeriodStatus.readyToFinish) {
            return;
          }
          await _gameRepository.applyActiveElapsedTime(
            profileId: profileId,
            periodId: period.id!,
            elapsed: elapsed,
          );
        })
        .catchError((_) {});
    return _pending;
  }
}
