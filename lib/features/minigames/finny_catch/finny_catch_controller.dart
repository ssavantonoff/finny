import 'dart:async';
import 'dart:math';

import 'package:finny/models/game_state.dart';
import 'package:flutter/foundation.dart';

import 'finny_catch_engine.dart';
import 'finny_catch_models.dart';
import 'finny_catch_rules.dart';

typedef FinnyCatchRewardWriter = Future<GameState> Function({
  required int profileId,
  required int amount,
  required String runId,
});

class FinnyCatchController extends ChangeNotifier {
  FinnyCatchController({
    required this.profileId,
    required this.grantReward,
    DateTime Function()? now,
    String Function()? runIdFactory,
    int Function()? seedFactory,
    this.autoTick = true,
  }) : _now = now ?? DateTime.now,
       _runIdFactory = runIdFactory ?? _newRunId,
       _seedFactory = seedFactory ?? (() => Random.secure().nextInt(1 << 32)) {
    _runId = _runIdFactory();
    _engine = FinnyCatchEngine(seed: _seedFactory());
  }

  static int _runSequence = 0;
  static String _newRunId() =>
      'finny-catch-${DateTime.now().toUtc().microsecondsSinceEpoch}-${_runSequence++}-${Random.secure().nextInt(1 << 32)}';

  final int profileId;
  final FinnyCatchRewardWriter grantReward;
  final DateTime Function() _now;
  final String Function() _runIdFactory;
  final int Function() _seedFactory;
  final bool autoTick;
  late FinnyCatchEngine _engine;
  late String _runId;
  FinnyCatchPhase _phase = FinnyCatchPhase.prepare;
  FinnyCatchPhase? _pausedFrom;
  Timer? _ticker;
  DateTime? _phaseStartedAt;
  Duration _countdownElapsed = Duration.zero;
  Duration _playElapsed = Duration.zero;
  double _finnyX = 0.5;
  double _fieldWidth = 360;
  int? _rewardAmount;
  bool _rewardGranted = false;
  bool _savingReward = false;
  String? _rewardError;
  bool _disposed = false;

  FinnyCatchState get state => FinnyCatchState(
    phase: _phase,
    score: _engine.score,
    remainingSeconds: _phase == FinnyCatchPhase.result
        ? 0
        : (FinnyCatchRules.roundDuration.inMilliseconds -
                          _playElapsed.inMilliseconds)
                      .clamp(0, FinnyCatchRules.roundDuration.inMilliseconds)
                      .toDouble()
                      .toInt() ~/
                  1000 +
              (_playElapsed.inMilliseconds % 1000 == 0 ? 0 : 1),
    finnyX: _finnyX,
    objects:
        _phase == FinnyCatchPhase.playing ||
            _phase == FinnyCatchPhase.result ||
            (_phase == FinnyCatchPhase.paused &&
                _pausedFrom == FinnyCatchPhase.playing)
        ? _engine.activeObjects
        : const [],
    difficultyPhase: _engine.difficultyPhase,
    runId: _runId,
    countdownText: _phase == FinnyCatchPhase.countdown
        ? _countdownLabel(_countdownElapsed)
        : null,
    rewardAmount: _rewardAmount,
    rewardGranted: _rewardGranted,
    savingReward: _savingReward,
    rewardError: _rewardError,
  );

  static String _countdownLabel(Duration elapsed) {
    if (elapsed < const Duration(milliseconds: 500)) return '3';
    if (elapsed < const Duration(milliseconds: 1000)) return '2';
    if (elapsed < const Duration(milliseconds: 1500)) return '1';
    return 'Старт!';
  }

  void setFieldWidth(double width) {
    if (width <= 0) return;
    _fieldWidth = width;
    _finnyX = _clampFinnyX(_finnyX);
  }

  double get finnyVisualWidth => min(162, _fieldWidth * 0.40);
  double get catchHalfWidth => finnyVisualWidth * 1.2 / (2 * _fieldWidth);

  double _clampFinnyX(double x) => x.clamp(
    finnyVisualWidth / (2 * _fieldWidth),
    1 - finnyVisualWidth / (2 * _fieldWidth),
  );

  void start() {
    if (_phase != FinnyCatchPhase.prepare) return;
    _phase = FinnyCatchPhase.countdown;
    _countdownElapsed = Duration.zero;
    _phaseStartedAt = _now();
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (autoTick) {
      _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => tick());
    }
  }

  void tick() {
    if (_disposed || _phaseStartedAt == null) return;
    final elapsedSinceStart = _now().difference(_phaseStartedAt!);
    if (_phase == FinnyCatchPhase.countdown) {
      final total = _countdownElapsed + elapsedSinceStart;
      if (total < FinnyCatchRules.countdownDuration) {
        _countdownElapsed = total;
        _phaseStartedAt = _now();
        notifyListeners();
        return;
      }
      _phase = FinnyCatchPhase.playing;
      final overflow = total - FinnyCatchRules.countdownDuration;
      _phaseStartedAt = _now().subtract(overflow);
      _countdownElapsed = FinnyCatchRules.countdownDuration;
      _playElapsed = Duration.zero;
    }
    if (_phase != FinnyCatchPhase.playing) return;
    final total = _playElapsed + _now().difference(_phaseStartedAt!);
    final bounded = total > FinnyCatchRules.roundDuration
        ? FinnyCatchRules.roundDuration
        : total;
    _engine.advance(bounded, finnyX: _finnyX, catchHalfWidth: catchHalfWidth);
    _playElapsed = bounded;
    _phaseStartedAt = _now();
    if (bounded == FinnyCatchRules.roundDuration) {
      _endRound();
    } else {
      notifyListeners();
    }
  }

  void moveFinny(double normalizedX) {
    if (_phase != FinnyCatchPhase.playing) return;
    _finnyX = _clampFinnyX(normalizedX);
    _engine.advance(
      _playElapsed,
      finnyX: _finnyX,
      catchHalfWidth: catchHalfWidth,
    );
    notifyListeners();
  }

  void pause() {
    if (_phase != FinnyCatchPhase.playing &&
        _phase != FinnyCatchPhase.countdown) {
      return;
    }
    final additional = _now().difference(_phaseStartedAt!);
    if (_phase == FinnyCatchPhase.playing) {
      _playElapsed += additional;
      if (_playElapsed >= FinnyCatchRules.roundDuration) {
        _playElapsed =
            FinnyCatchRules.roundDuration - const Duration(microseconds: 1);
      }
    } else {
      _countdownElapsed += additional;
      if (_countdownElapsed >= FinnyCatchRules.countdownDuration) {
        _countdownElapsed =
            FinnyCatchRules.countdownDuration - const Duration(microseconds: 1);
      }
    }
    _pausedFrom = _phase;
    _phase = FinnyCatchPhase.paused;
    _phaseStartedAt = null;
    _ticker?.cancel();
    notifyListeners();
  }

  void resume() {
    if (_phase != FinnyCatchPhase.paused || _pausedFrom == null) return;
    _phase = _pausedFrom!;
    _pausedFrom = null;
    _phaseStartedAt = _now();
    _startTicker();
    notifyListeners();
  }

  void _endRound() {
    _ticker?.cancel();
    _phaseStartedAt = null;
    _phase = FinnyCatchPhase.result;
    _rewardAmount = FinnyCatchRules.rewardForScore(_engine.score);
    notifyListeners();
    unawaited(retryReward());
  }

  Future<void> retryReward() async {
    if (_phase != FinnyCatchPhase.result ||
        _rewardGranted ||
        _savingReward ||
        _rewardAmount == null) {
      return;
    }
    _savingReward = true;
    _rewardError = null;
    notifyListeners();
    try {
      await grantReward(
        profileId: profileId,
        amount: _rewardAmount!,
        runId: _runId,
      );
      _rewardGranted = true;
    } catch (_) {
      _rewardError = 'Награда не сохранена. Попробуй ещё раз.';
    } finally {
      _savingReward = false;
      if (!_disposed) notifyListeners();
    }
  }

  void replay() {
    if (_phase != FinnyCatchPhase.result || !_rewardGranted) return;
    _runId = _runIdFactory();
    _engine = FinnyCatchEngine(seed: _seedFactory());
    _phase = FinnyCatchPhase.prepare;
    _pausedFrom = null;
    _phaseStartedAt = null;
    _countdownElapsed = Duration.zero;
    _playElapsed = Duration.zero;
    _finnyX = 0.5;
    _rewardAmount = null;
    _rewardGranted = false;
    _savingReward = false;
    _rewardError = null;
    notifyListeners();
  }

  void abort() {
    _ticker?.cancel();
    _phaseStartedAt = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
