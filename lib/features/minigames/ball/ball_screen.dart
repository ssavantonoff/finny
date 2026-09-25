import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:finny/models/ball_reward.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ball_session.dart';

/// The visual Ball game. All ownership and reward decisions live in the domain
/// service; this screen only owns the transient eight-return session.
class BallScreen extends ConsumerStatefulWidget {
  const BallScreen({
    super.key,
    this.checkAccess,
    this.completeSession,
    this.loadPet,
    this.seedFactory,
    this.sessionIdFactory,
    this.onClose,
  });

  /// Test seams. Production routes use [ballRewardServiceProvider].
  final Future<BallGameAccess> Function(int profileId)? checkAccess;
  final Future<BallRewardResult> Function(
    BallGameAccess access,
    BallSession session,
  )?
  completeSession;
  final Future<Pet?> Function(int profileId)? loadPet;
  final int Function()? seedFactory;
  final String Function()? sessionIdFactory;
  final VoidCallback? onClose;

  @override
  ConsumerState<BallScreen> createState() => _BallScreenState();
}

class _BallScreenState extends ConsumerState<BallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  BallGameAccess? _access;
  Pet? _pet;
  BallSession? _session;
  BallRewardResult? _rewardResult;
  Duration _elapsed = Duration.zero;
  bool _loading = true;
  bool _rewardPending = false;
  String? _accessError;
  String? _rewardError;
  String? _interruptionMessage;
  int? _entryProfileId;
  bool _exitDialogOpen = false;
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
                  .read(ballRewardServiceProvider)
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
            ? 'Чтобы играть с мячом, сначала купи его в магазине.'
            : 'Сейчас не удалось открыть игру с мячом. Вернись к вещам и попробуй ещё раз.';
      });
    }
  }

  void _onTick(Duration elapsed) {
    final session = _session;
    if (!mounted || session == null) return;
    if (session.phase == BallSessionPhase.aborted ||
        session.phase == BallSessionPhase.completed) {
      _ticker.stop();
      return;
    }
    _elapsed = elapsed;
    session.advance(elapsed);
    if (session.phase == BallSessionPhase.completed) {
      _ticker.stop();
      setState(() {});
      unawaited(_submitReward());
    } else {
      setState(() {});
    }
  }

  void _startSession() {
    if (_access == null || _loading) return;
    _ticker.stop();
    _sessionOrdinal += 1;
    final seed =
        widget.seedFactory?.call() ??
        DateTime.now().microsecondsSinceEpoch + _sessionOrdinal;
    final sessionId =
        widget.sessionIdFactory?.call() ??
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-$_sessionOrdinal';
    final session = BallSession(seed: seed, sessionId: sessionId)..start();
    setState(() {
      _session = session;
      _elapsed = Duration.zero;
      _rewardResult = null;
      _rewardError = null;
      _rewardPending = false;
      _interruptionMessage = null;
    });
    _ticker.start();
  }

  void _tap() {
    final session = _session;
    if (session == null || session.phase != BallSessionPhase.active) return;
    session.tap(_elapsed);
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
      // Retain this same completed session for every retry. The domain derives
      // its idempotent operation identity from session.completion.sessionId.
      final result =
          await (widget.completeSession?.call(access, session!) ??
              ref
                  .read(ballRewardServiceProvider)
                  .completeSession(access: access, session: session!));
      if (!mounted ||
          ref.read(activeProfileIdProvider) != access.profileId ||
          _session != session) {
        return;
      }
      setState(() {
        _rewardResult = result;
        _rewardPending = false;
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
        session.phase == BallSessionPhase.completed ||
        session.phase == BallSessionPhase.aborted) {
      return;
    }
    // A transient run is discarded on interruption. Backgrounding can never
    // complete it or grant a systemic effect.
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
      // Navigation remains available even when a fresh Things load fails.
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
      final access = _access;
      if (next != (access?.profileId ?? _entryProfileId)) {
        _invalidateForProfileChange();
      }
    });
    final session = _session;
    final isResult = session?.phase == BallSessionPhase.completed;
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

  Widget _header(BallSession? session) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      key: const Key('ball-header'),
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
            left: 76,
            right: 76,
            child: Center(
              child: Text(
                'Игра с мячом',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            child: IconButton.filledTonal(
              key: const Key('ball-back'),
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
          Positioned(
            right: 10,
            child: SizedBox(
              width: 58,
              child: session == null
                  ? const SizedBox.shrink()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '${session.opportunityNumber} / 8',
                          key: const Key('ball-progress'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
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
            const _BallSprite(size: 56),
            const SizedBox(height: 16),
            Text(
              _accessError!,
              key: const Key('ball-access-denied'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            _BallButton(label: 'Вернуться к вещам', onPressed: _goThings),
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Нажимай, когда мяч окажется в зоне удара.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
            left: 30,
            right: 30,
            top: height * 0.29,
            height: height * 0.65,
            child: _FinnyImage(pet: _pet),
          ),
          Positioned(
            right: 30,
            bottom: height * 0.05,
            child: const _BallSprite(size: 72),
          ),
        ],
      );
    },
  );

  Widget _gameScene(BallSession session) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final ballSize = (width * 0.19).clamp(54.0, 72.0);
      final x = width * (0.5 + session.currentOpportunity.horizontalOffset);
      final y = height * (0.28 + session.progress * 0.58);
      return GestureDetector(
        key: const Key('ball-tap-area'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: Stack(
          children: [
            Positioned(
              top: height * 0.06,
              left: width * 0.15,
              right: width * 0.15,
              height: height * 0.44,
              child: _FinnyImage(pet: _pet),
            ),
            Positioned(
              left: width * 0.07,
              right: width * 0.07,
              top: height * 0.68,
              height: height * 0.19,
              child: const _TimingZone(),
            ),
            if (session.phase == BallSessionPhase.active)
              Positioned(
                left: (x - ballSize / 2).clamp(0.0, width - ballSize),
                top: (y - ballSize / 2).clamp(0.0, height - ballSize),
                child: _BallSprite(size: ballSize),
              ),
            if (session.phase == BallSessionPhase.feedback ||
                session.phase == BallSessionPhase.transitioning)
              Positioned(
                left: 16,
                right: 16,
                top: height * 0.57,
                child: Text(
                  switch (session.lastOutcome) {
                    BallOutcome.perfect => 'Идеально!',
                    BallOutcome.good => 'Хорошо!',
                    _ => 'Ничего страшного! Лови следующий.',
                  },
                  key: const Key('ball-feedback'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    shadows: [Shadow(color: Colors.white, blurRadius: 10)],
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: Text(
                'Коснись экрана, когда мяч в зоне удара',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  backgroundColor: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _resultScene(BallSession session) => LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
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
                    key: Key('ball-result'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ResultStat(
                    leading: const _BallSprite(size: 34),
                    label: 'Точные передачи',
                    value: '${session.accuratePasses} / 8',
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
            height: constraints.maxHeight * 0.41,
            child: _FinnyImage(pet: _pet),
          ),
        ],
      );
    },
  );

  Widget _rewardMessage() {
    final result = _rewardResult;
    final String text;
    if (_rewardPending) {
      text = 'Сохраняем результат игры…';
    } else if (_rewardError != null) {
      text = _rewardError!;
    } else if (result == null) {
      text = 'Проверяем награду…';
    } else {
      text = switch (result.status) {
        BallRewardStatus.applied =>
          'Настроение Финни +${result.actualMoodDelta}',
        BallRewardStatus.capped =>
          'Финни уже в отличном настроении! Награда учтена.',
        BallRewardStatus.alreadyRewarded =>
          _access?.mode == BallGameMode.freePlay
              ? 'Играй ещё! Награда в свободной игре уже получена.'
              : 'Играй ещё! Награда за этот период уже получена.',
        BallRewardStatus.confirmedPreviously =>
          'Награда за эту игру уже сохранена.',
      };
    }
    return Container(
      key: const Key('ball-reward-message'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
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
    required BallSession? session,
  }) {
    if (session != null && !isResult) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isResult)
            _BallButton(
              key: const Key('ball-start'),
              label: 'Начать',
              onPressed: _startSession,
            )
          else ...[
            _BallButton(
              key: Key(
                _rewardError == null ? 'ball-replay' : 'ball-retry-reward',
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
            _BallButton(
              key: const Key('ball-back-to-things'),
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
        key: const Key('ball-room-background'),
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
      key: Key('ball-finny-stage-$stage'),
      fit: BoxFit.contain,
      semanticLabel: '${pet?.name ?? 'Финни'} играет с мячом',
    );
  }
}

class _BallSprite extends StatelessWidget {
  const _BallSprite({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/minigames/ball/ball.png',
    key: const Key('ball-art'),
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'Мяч',
  );
}

class _TimingZone extends StatelessWidget {
  const _TimingZone();

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('ball-timing-zone'),
    painter: _TimingZonePainter(),
    child: const Center(
      child: Text(
        'Зона удара',
        style: TextStyle(
          color: AppColors.primaryDark,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.white, blurRadius: 10)],
        ),
      ),
    ),
  );
}

class _TimingZonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outer = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawOval(
      outer,
      Paint()..color = AppColors.primary.withValues(alpha: 0.24),
    );
    canvas.drawOval(
      outer.deflate(2),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      outer.deflate(22),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TimingZonePainter oldDelegate) => false;
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

class _BallButton extends StatelessWidget {
  const _BallButton({
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
