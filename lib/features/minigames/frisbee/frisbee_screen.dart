import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:finny/models/frisbee_reward.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'frisbee_session.dart';

/// Transient swipe game. Ownership and the systemic effect belong to the
/// reward service, never to this widget or its gameplay model.
class FrisbeeScreen extends ConsumerStatefulWidget {
  const FrisbeeScreen({
    super.key,
    this.checkAccess,
    this.completeSession,
    this.loadPet,
    this.seedFactory,
    this.sessionIdFactory,
    this.onClose,
  });

  /// Narrow test seams; production routes use the same domain providers.
  final Future<FrisbeeGameAccess> Function(int profileId)? checkAccess;
  final Future<FrisbeeRewardResult> Function(
    FrisbeeGameAccess access,
    FrisbeeSession session,
  )?
  completeSession;
  final Future<Pet?> Function(int profileId)? loadPet;
  final int Function()? seedFactory;
  final String Function()? sessionIdFactory;
  final VoidCallback? onClose;

  @override
  ConsumerState<FrisbeeScreen> createState() => _FrisbeeScreenState();
}

class _FrisbeeScreenState extends ConsumerState<FrisbeeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  FrisbeeGameAccess? _access;
  Pet? _pet;
  FrisbeeSession? _session;
  FrisbeeRewardResult? _rewardResult;
  Duration _elapsed = Duration.zero;
  bool _loading = true;
  bool _rewardPending = false;
  bool _exitDialogOpen = false;
  String? _accessError;
  String? _rewardError;
  String? _interruptionMessage;
  String? _gestureHint;
  int? _entryProfileId;
  int _sessionOrdinal = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadAccess());
  }

  Future<void> _loadAccess() async {
    final profileId = ref.read(activeProfileIdProvider);
    _entryProfileId = profileId;
    if (profileId == null) {
      setState(() {
        _loading = false;
        _accessError = 'Сначала выбери профиль, чтобы играть с Финни.';
      });
      return;
    }
    try {
      final access =
          await (widget.checkAccess?.call(profileId) ??
              ref
                  .read(frisbeeRewardServiceProvider)
                  .checkAccess(profileId: profileId));
      final pet =
          await (widget.loadPet?.call(profileId) ??
              ref.read(gameRepositoryProvider).getPet(profileId));
      if (!mounted || ref.read(activeProfileIdProvider) != profileId) return;
      setState(() {
        _access = access;
        _pet = pet;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || ref.read(activeProfileIdProvider) != profileId) return;
      setState(() {
        _loading = false;
        _accessError = error is PetItemNotOwnedException
            ? 'Чтобы играть с фрисби, сначала купи его в магазине.'
            : 'Сейчас не удалось открыть игру с фрисби. Вернись к вещам и попробуй ещё раз.';
      });
    }
  }

  void _onTick(Duration elapsed) {
    final session = _session;
    if (!mounted || session == null) return;
    if (session.phase == FrisbeeSessionPhase.aborted ||
        session.phase == FrisbeeSessionPhase.completed) {
      _ticker.stop();
      return;
    }
    _elapsed = elapsed;
    session.advance(elapsed);
    if (session.phase == FrisbeeSessionPhase.completed) {
      _ticker.stop();
      setState(() {});
      unawaited(_submitReward());
    } else {
      setState(() {});
    }
  }

  void _startSession() {
    if (_access == null || _loading || _rewardPending || _rewardError != null) {
      return;
    }
    _ticker.stop();
    _sessionOrdinal += 1;
    final seed =
        widget.seedFactory?.call() ??
        DateTime.now().microsecondsSinceEpoch + _sessionOrdinal;
    final sessionId =
        widget.sessionIdFactory?.call() ??
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-$_sessionOrdinal';
    final session = FrisbeeSession(seed: seed, sessionId: sessionId)..start();
    setState(() {
      _session = session;
      _elapsed = Duration.zero;
      _rewardResult = null;
      _rewardError = null;
      _interruptionMessage = null;
      _gestureHint = null;
    });
    _ticker.start();
  }

  FrisbeePoint _normalized(Offset local, Size size) => FrisbeePoint(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _pointerDown(PointerDownEvent event, Size size) {
    final session = _session;
    if (session == null) return;
    if (session.beginGesture(
      event.pointer,
      _normalized(event.localPosition, size),
    )) {
      setState(() => _gestureHint = null);
    }
  }

  void _pointerMove(PointerMoveEvent event, Size size) {
    final session = _session;
    if (session == null) return;
    if (session.updateGesture(
      event.pointer,
      _normalized(event.localPosition, size),
    )) {
      setState(() {});
    }
  }

  void _pointerUp(PointerUpEvent event, Size size) {
    final session = _session;
    if (session == null) return;
    final result = session.releaseGesture(
      event.pointer,
      _normalized(event.localPosition, size),
      _elapsed,
    );
    if (result == FrisbeeGestureResult.ignored) return;
    setState(() {
      _gestureHint = switch (result) {
        FrisbeeGestureResult.invalidShort => 'Проведи пальцем чуть дальше.',
        FrisbeeGestureResult.invalidDirection =>
          'Проведи фрисби вверх, к Финни.',
        _ => null,
      };
    });
  }

  void _pointerCancel(PointerCancelEvent event) {
    final session = _session;
    if (session == null) return;
    session.cancelGesture(event.pointer);
    setState(() {});
  }

  Future<void> _submitReward() async {
    final access = _access;
    final session = _session;
    if (access == null ||
        session?.completion == null ||
        _rewardPending ||
        _rewardResult != null) {
      return;
    }
    setState(() {
      _rewardPending = true;
      _rewardError = null;
    });
    try {
      // Retain the completed session and its ID on ambiguous retry.
      final result =
          await (widget.completeSession?.call(access, session!) ??
              ref
                  .read(frisbeeRewardServiceProvider)
                  .completeSession(access: access, session: session!));
      if (!mounted ||
          ref.read(activeProfileIdProvider) != access.profileId ||
          _session != session) {
        return;
      }
      setState(() {
        _rewardResult = result;
        _rewardPending = false;
        _pet = result.pet;
      });
    } catch (_) {
      if (!mounted ||
          ref.read(activeProfileIdProvider) != access.profileId ||
          _session != session) {
        return;
      }
      setState(() {
        _rewardPending = false;
        _rewardError = 'Не удалось подтвердить награду. Повтори сохранение.';
      });
    }
  }

  void _invalidateForProfileChange() {
    _ticker.stop();
    _session?.abort();
    setState(() {
      _access = null;
      _session = null;
      _rewardResult = null;
      _accessError = 'Профиль изменился. Вернись к вещам этого профиля.';
      _loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }
    final session = _session;
    if (session == null ||
        session.phase == FrisbeeSessionPhase.completed ||
        session.phase == FrisbeeSessionPhase.aborted) {
      return;
    }
    _ticker.stop();
    session.abort();
    if (!mounted) return;
    setState(() {
      _session = null;
      _interruptionMessage = 'Игра прервалась. Начни заново!';
    });
  }

  Future<void> _goThings() async {
    if (_exitDialogOpen) return;
    if (_session?.completion != null &&
        (_rewardPending || _rewardError != null)) {
      _exitDialogOpen = true;
      if (_rewardPending) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Сохраняем награду'),
            content: const Text('Подожди, пока результат игры сохранится.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
        _exitDialogOpen = false;
        return;
      }
      final leave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Награда не подтверждена'),
          content: const Text(
            'Пока неясно, сохранилась ли награда. Можно повторить сохранение без повторной игры.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Повторить сохранение'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Выйти без подтверждения'),
            ),
          ],
        ),
      );
      _exitDialogOpen = false;
      if (!mounted) return;
      if (leave != true) {
        unawaited(_submitReward());
        return;
      }
    }
    _ticker.stop();
    _session?.abort();
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    try {
      await ref.read(thingsControllerProvider.notifier).load();
    } catch (_) {
      // Keep navigation available even if a fresh Things load fails.
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/things');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.stop();
    _ticker.dispose();
    _session?.abort();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(activeProfileIdProvider, (_, next) {
      if (next != (_access?.profileId ?? _entryProfileId)) {
        _invalidateForProfileChange();
      }
    });
    final session = _session;
    final isResult = session?.phase == FrisbeeSessionPhase.completed;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_goThings());
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _RoomBackground(),
            SafeArea(
              child: Column(
                children: [
                  _header(session),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _accessError != null
                        ? _accessDenied()
                        : isResult
                        ? _resultScene(session!)
                        : session == null
                        ? _startScene()
                        : _gameScene(session),
                  ),
                  if (!_loading && _accessError == null)
                    _bottomActions(isResult: isResult, session: session),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(FrisbeeSession? session) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      key: const Key('frisbee-header'),
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F0C69),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            left: 92,
            right: 92,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Игра с фрисби',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            child: IconButton.filledTonal(
              key: const Key('frisbee-back'),
              tooltip: 'Вернуться к вещам',
              onPressed: _goThings,
              style: IconButton.styleFrom(
                minimumSize: const Size(50, 50),
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primaryDark,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 28),
            ),
          ),
          if (session != null)
            Positioned(
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Text(
                    'Бросок ${session.throwNumber} / 6',
                    key: const Key('frisbee-progress'),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _accessDenied() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: _WhiteCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FrisbeeSprite(size: 56),
            const SizedBox(height: 16),
            Text(
              _accessError!,
              key: const Key('frisbee-access-denied'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            _GameButton(label: 'Вернуться к вещам', onPressed: _goThings),
          ],
        ),
      ),
    ),
  );

  Widget _startScene() => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.maxHeight;
      return Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 16,
            child: _WhiteCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Поиграем с Финни?',
                    key: Key('frisbee-start-prompt'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Проведи пальцем от фрисби в сторону Финни.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Постарайся бросить точно, чтобы Финни поймал фрисби.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_interruptionMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _interruptionMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            top: height * 0.37,
            height: height * 0.48,
            child: _FinnyImage(pet: _pet),
          ),
          Positioned(
            left: 38,
            bottom: height * 0.04,
            child: const _FrisbeeSprite(size: 98),
          ),
        ],
      );
    },
  );

  Widget _gameScene(FrisbeeSession session) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final discSize = (size.width * 0.22).clamp(62.0, 88.0);
      final discPosition =
          session.flightPosition ??
          session.gesturePosition ??
          FrisbeeSession.launchPoint;
      return Listener(
        key: const Key('frisbee-gesture-area'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _pointerDown(event, size),
        onPointerMove: (event) => _pointerMove(event, size),
        onPointerUp: (event) => _pointerUp(event, size),
        onPointerCancel: _pointerCancel,
        child: Stack(
          children: [
            Positioned(
              left: size.width * 0.12,
              right: size.width * 0.12,
              top: size.height * 0.05,
              height: size.height * 0.48,
              child: _FinnyImage(pet: _pet),
            ),
            Positioned(
              left:
                  size.width *
                  (session.currentTarget.x - FrisbeeSession.goodRadiusX),
              top:
                  size.height *
                  (session.currentTarget.y - FrisbeeSession.goodRadiusY),
              width: size.width * FrisbeeSession.goodRadiusX * 2,
              height: size.height * FrisbeeSession.goodRadiusY * 2,
              child: const _CatchTarget(),
            ),
            if (session.phase == FrisbeeSessionPhase.flying)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FlightPathPainter(
                      start: FrisbeeSession.launchPoint,
                      end: session.landingPoint!,
                      progress: session.flightProgress,
                    ),
                  ),
                ),
              ),
            if (session.phase == FrisbeeSessionPhase.ready ||
                session.phase == FrisbeeSessionPhase.aiming ||
                session.phase == FrisbeeSessionPhase.flying)
              Positioned(
                left: (size.width * discPosition.x - discSize / 2).clamp(
                  0.0,
                  size.width - discSize,
                ),
                top: (size.height * discPosition.y - discSize / 2).clamp(
                  0.0,
                  size.height - discSize,
                ),
                child: _FrisbeeSprite(size: discSize),
              ),
            if (session.phase == FrisbeeSessionPhase.feedback)
              Positioned(
                left: 16,
                right: 16,
                top: size.height * 0.53,
                child: Text(
                  switch (session.lastOutcome) {
                    FrisbeeOutcome.perfect => 'Идеально!',
                    FrisbeeOutcome.good => 'Хорошо!',
                    _ => 'Почти!',
                  },
                  key: const Key('frisbee-feedback'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    shadows: [Shadow(color: Colors.white, blurRadius: 10)],
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 15,
              child: Text(
                _gestureHint ?? 'Проведи фрисби вверх, к Финни',
                key: const Key('frisbee-instruction'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  backgroundColor: Colors.white.withValues(alpha: 0.76),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _resultScene(FrisbeeSession session) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned(
          left: 16,
          right: 16,
          top: 14,
          child: _WhiteCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Отличная игра!',
                  key: Key('frisbee-result'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                _ResultStat(
                  leading: const _FrisbeeSprite(size: 34),
                  label: 'Удачные броски',
                  value: '${session.successfulThrows} / 6',
                ),
                const SizedBox(height: 8),
                _ResultStat(
                  leading: const Icon(
                    Icons.star_rounded,
                    color: AppColors.primary,
                    size: 34,
                  ),
                  label: 'Лучшая серия',
                  value: '${session.bestStreak}',
                ),
                const SizedBox(height: 10),
                _rewardMessage(),
              ],
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          bottom: 0,
          height: constraints.maxHeight * 0.40,
          child: _FinnyImage(pet: _pet),
        ),
      ],
    ),
  );

  Widget _rewardMessage() {
    final result = _rewardResult;
    final String message;
    if (_rewardPending) {
      message = 'Сохраняем результат игры…';
    } else if (_rewardError != null) {
      message = _rewardError!;
    } else if (result == null) {
      message = 'Проверяем награду…';
    } else {
      message = switch (result.status) {
        FrisbeeRewardStatus.applied =>
          'Настроение Финни +${result.actualMoodDelta}',
        FrisbeeRewardStatus.capped =>
          'Финни уже в отличном настроении! Награда учтена.',
        FrisbeeRewardStatus.alreadyRewarded =>
          _access?.mode == FrisbeeGameMode.freePlay
              ? 'Играй ещё! Награда в свободной игре уже получена.'
              : 'Играй ещё! Награда за этот период уже получена.',
        FrisbeeRewardStatus.confirmedPreviously =>
          'Награда за эту игру уже сохранена.',
      };
    }
    return Container(
      key: const Key('frisbee-reward-message'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _bottomActions({
    required bool isResult,
    required FrisbeeSession? session,
  }) {
    if (session != null && !isResult) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isResult)
            _GameButton(
              key: const Key('frisbee-start'),
              label: 'Начать',
              onPressed: _startSession,
            )
          else ...[
            _GameButton(
              key: Key(
                _rewardError == null
                    ? 'frisbee-replay'
                    : 'frisbee-retry-reward',
              ),
              label: _rewardError == null
                  ? 'Играть ещё раз'
                  : 'Повторить сохранение',
              onPressed: _rewardPending
                  ? null
                  : _rewardError == null
                  ? _startSession
                  : _submitReward,
            ),
            const SizedBox(height: 8),
            _GameButton(
              key: const Key('frisbee-back-to-things'),
              label: 'Вернуться к вещам',
              onPressed: _goThings,
              secondary: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomBackground extends StatelessWidget {
  const _RoomBackground();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/images/home/room_base.png',
        key: const Key('frisbee-room-background'),
        fit: BoxFit.cover,
      ),
      ColoredBox(color: AppColors.primaryLight.withValues(alpha: 0.17)),
    ],
  );
}

class _FinnyImage extends StatelessWidget {
  const _FinnyImage({required this.pet});

  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final stage = (pet?.developmentStage ?? 3).clamp(1, 3);
    return Image.asset(
      FinnyRoomScene.assetForStage(stage),
      key: Key('frisbee-finny-stage-$stage'),
      fit: BoxFit.contain,
      semanticLabel: '${pet?.name ?? 'Финни'} играет с фрисби',
    );
  }
}

/// Center panel of the existing three-toy production sheet.
class _FrisbeeSprite extends StatelessWidget {
  const _FrisbeeSprite({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('frisbee-art'),
    width: size,
    height: size,
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: size * 3,
        maxWidth: size * 3,
        minHeight: size,
        maxHeight: size,
        child: Image.asset(
          'assets/images/things/toys_sheet.png',
          width: size * 3,
          height: size,
          fit: BoxFit.fill,
          semanticLabel: 'Фрисби',
        ),
      ),
    ),
  );
}

class _CatchTarget extends StatelessWidget {
  const _CatchTarget();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      key: const Key('frisbee-catch-target'),
      painter: const _CatchTargetPainter(),
      child: const Center(
        child: Text(
          'Финни',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.white, blurRadius: 9)],
          ),
        ),
      ),
    ),
  );
}

/// Outer oval is exactly the model's Good ellipse in scene coordinates.
class _CatchTargetPainter extends CustomPainter {
  const _CatchTargetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawOval(
      oval,
      Paint()..color = AppColors.primaryLight.withValues(alpha: 0.25),
    );
    canvas.drawOval(
      oval.deflate(2),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final perfect = Rect.fromCenter(
      center: oval.center,
      width:
          size.width *
          FrisbeeSession.perfectRadiusX /
          FrisbeeSession.goodRadiusX,
      height:
          size.height *
          FrisbeeSession.perfectRadiusY /
          FrisbeeSession.goodRadiusY,
    );
    canvas.drawOval(
      perfect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CatchTargetPainter oldDelegate) => false;
}

class _FlightPathPainter extends CustomPainter {
  const _FlightPathPainter({
    required this.start,
    required this.end,
    required this.progress,
  });

  final FrisbeePoint start;
  final FrisbeePoint end;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(start.x * size.width, start.y * size.height);
    final target = Offset(end.x * size.width, end.y * size.height);
    final control = Offset(
      (origin.dx + target.dx) / 2,
      (start.y < end.y ? start.y : end.y) * size.height - size.height * 0.17,
    );
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _FlightPathPainter oldDelegate) =>
      start != oldDelegate.start ||
      end != oldDelegate.end ||
      progress != oldDelegate.progress;
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x220F0C69),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.leading,
    required this.label,
    required this.value,
  });

  final Widget leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    ),
  );
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? AppColors.surface : AppColors.primary,
        foregroundColor: secondary ? AppColors.primaryDark : AppColors.surface,
        disabledBackgroundColor: AppColors.primaryLight,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
