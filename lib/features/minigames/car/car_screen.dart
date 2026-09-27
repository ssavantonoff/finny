import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:finny/models/car_reward.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'car_session.dart';

/// Six short, time-based sections. The session owns the game rules and the
/// reward service owns the systemic effect; this widget only presents them.
class CarScreen extends ConsumerStatefulWidget {
  const CarScreen({
    super.key,
    this.checkAccess,
    this.completeSession,
    this.loadPet,
    this.seedFactory,
    this.sessionIdFactory,
    this.onClose,
  });

  /// Test seams; the production route uses the same domain providers.
  final Future<CarGameAccess> Function(int profileId)? checkAccess;
  final Future<CarRewardResult> Function(
    CarGameAccess access,
    CarSession session,
  )?
  completeSession;
  final Future<Pet?> Function(int profileId)? loadPet;
  final int Function()? seedFactory;
  final String Function()? sessionIdFactory;
  final VoidCallback? onClose;

  @override
  ConsumerState<CarScreen> createState() => _CarScreenState();
}

class _CarScreenState extends ConsumerState<CarScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  CarGameAccess? _access;
  Pet? _pet;
  CarSession? _session;
  CarRewardResult? _rewardResult;
  Duration _elapsed = Duration.zero;
  bool _loading = true;
  bool _rewardPending = false;
  bool _exitDialogOpen = false;
  String? _accessError;
  String? _rewardError;
  String? _interruptionMessage;
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
                  .read(carRewardServiceProvider)
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
            ? 'Чтобы играть с машинкой, сначала купи её в магазине.'
            : 'Сейчас не удалось открыть игру с машинкой. Вернись к вещам и попробуй ещё раз.';
      });
    }
  }

  void _onTick(Duration elapsed) {
    final session = _session;
    if (!mounted || session == null) return;
    if (session.phase == CarSessionPhase.aborted ||
        session.phase == CarSessionPhase.completed) {
      _ticker.stop();
      return;
    }
    _elapsed = elapsed;
    session.advance(elapsed);
    if (session.phase == CarSessionPhase.completed) {
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
    final session = CarSession(seed: seed, sessionId: sessionId)..start();
    setState(() {
      _session = session;
      _elapsed = Duration.zero;
      _rewardResult = null;
      _rewardError = null;
      _interruptionMessage = null;
    });
    _ticker.start();
  }

  double _normalizedX(Offset local, Size size) =>
      (local.dx / size.width).clamp(0.0, 1.0);

  void _pointerDown(PointerDownEvent event, Size size) {
    final session = _session;
    if (session == null) return;
    session.beginSteering(
      event.pointer,
      _normalizedX(event.localPosition, size),
      _elapsed,
    );
    setState(() {});
  }

  void _pointerMove(PointerMoveEvent event, Size size) {
    final session = _session;
    if (session == null) return;
    session.updateSteering(
      event.pointer,
      _normalizedX(event.localPosition, size),
      _elapsed,
    );
    setState(() {});
  }

  void _pointerUp(PointerUpEvent event) {
    _session?.endSteering(event.pointer, _elapsed);
    setState(() {});
  }

  void _pointerCancel(PointerCancelEvent event) {
    _session?.cancelSteering(event.pointer, _elapsed);
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
      // An ambiguous retry keeps this completed session and operation ID.
      final result =
          await (widget.completeSession?.call(access, session!) ??
              ref
                  .read(carRewardServiceProvider)
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
        session.phase == CarSessionPhase.completed ||
        session.phase == CarSessionPhase.aborted) {
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
      // Navigation stays available when a fresh Things load fails.
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
    final isResult = session?.phase == CarSessionPhase.completed;
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
                  _header(),
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

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      key: const Key('car-header'),
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
            left: 66,
            right: 12,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Игра с машинкой',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 23,
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
              key: const Key('car-back'),
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
            const _CarSprite(size: 72),
            const SizedBox(height: 16),
            Text(
              _accessError!,
              key: const Key('car-access-denied'),
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
      if (height < 410) {
        return SingleChildScrollView(
          key: const Key('car-compact-start'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              _startPromptCard(),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: _FinnyImage(pet: _pet)),
                    const SizedBox(width: 12),
                    const _CarSprite(size: 110),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Stack(
        children: [
          Positioned(left: 20, right: 20, top: 14, child: _startPromptCard()),
          Positioned(
            left: 28,
            right: 28,
            top: height * 0.38,
            height: height * 0.43,
            child: _FinnyImage(pet: _pet),
          ),
          Positioned(
            bottom: height * 0.025,
            left: 0,
            right: 0,
            child: const Center(child: _CarSprite(size: 115)),
          ),
        ],
      );
    },
  );

  Widget _startPromptCard() => _WhiteCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Поиграем с Финни?',
          key: Key('car-start-prompt'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Машинка едет вперёд сама.\nВеди её пальцем влево и вправо.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Постарайся проехать трассу, не задевая бортики.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (_interruptionMessage != null) ...[
          const SizedBox(height: 7),
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
  );

  Widget _gameScene(CarSession session) => LayoutBuilder(
    builder: (context, constraints) {
      final shortWide =
          constraints.maxWidth > constraints.maxHeight &&
          constraints.maxHeight < 420;
      final maxPlayWidth = shortWide
          ? (constraints.maxHeight * 1.7).clamp(240.0, 440.0)
          : 440.0;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxPlayWidth),
          child: LayoutBuilder(
            builder: (context, playConstraints) => _gameField(
              session,
              Size(playConstraints.maxWidth, playConstraints.maxHeight),
            ),
          ),
        ),
      );
    },
  );

  Widget _gameField(CarSession session, Size size) {
    final carWidth = (size.width * 0.22).clamp(48.0, 72.0);
    final carHeight = carWidth * 1.35;
    final carTop =
        size.height * (0.86 - session.sectionProgress * 0.66) - carHeight / 2;
    return Listener(
      key: const Key('car-steering-area'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _pointerDown(event, size),
      onPointerMove: (event) => _pointerMove(event, size),
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerCancel,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: const Key('car-track'),
              painter: _TrackPainter(section: session.currentSection),
            ),
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: _Pill(
                key: const Key('car-progress'),
                text: 'Участок ${session.sectionNumber} / 6',
              ),
            ),
          ),
          Positioned(
            top: size.height < 240 ? 2 : size.height * 0.11,
            left: size.height < 240 ? size.width * 0.80 : size.width * 0.39,
            width: size.height < 240 ? size.width * 0.18 : size.width * 0.22,
            height: size.height < 240 ? 50 : size.height * 0.16,
            child: IgnorePointer(child: _FinnyImage(pet: _pet)),
          ),
          Positioned(
            left: (size.width * session.carX - carWidth / 2).clamp(
              0.0,
              size.width - carWidth,
            ),
            top: carTop.clamp(0.0, size.height - carHeight),
            width: carWidth,
            height: carHeight,
            child: const IgnorePointer(
              child: CustomPaint(
                key: Key('car-top-down-art'),
                painter: _TopDownCarPainter(),
              ),
            ),
          ),
          if (session.phase == CarSessionPhase.feedback)
            Positioned(
              top: size.height < 240 ? null : size.height * 0.42,
              bottom: size.height < 240 ? 8 : null,
              left: 20,
              right: 20,
              child: _Pill(
                key: const Key('car-feedback'),
                text: switch (session.lastOutcome) {
                  CarOutcome.perfect => 'Идеально!',
                  CarOutcome.good => 'Хорошо!',
                  _ => 'Почти!',
                },
              ),
            ),
          if (size.height >= 240 &&
              session.resolvedSections == 0 &&
              _elapsed < const Duration(milliseconds: 2400))
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _Pill(
                key: const Key('car-tutorial-hint'),
                text: '☝  ← Веди пальцем влево и вправо →',
                small: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultScene(CarSession session) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const Key('car-result-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          _WhiteCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Отличная поездка!',
                  key: Key('car-result'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                _ResultStat(
                  leading: const _CarSprite(size: 36),
                  label: 'Удачные проезды',
                  value: '${session.successfulSections} / 6',
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
          const SizedBox(height: 8),
          SizedBox(
            height: (constraints.maxHeight * 0.38).clamp(120.0, 205.0),
            child: _FinnyImage(pet: _pet),
          ),
        ],
      ),
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
        CarRewardStatus.applied =>
          'Настроение Финни +${result.actualMoodDelta}',
        CarRewardStatus.capped =>
          'Финни уже в отличном настроении! Награда учтена.',
        CarRewardStatus.alreadyRewarded =>
          _access?.mode == CarGameMode.freePlay
              ? 'Играй ещё! Награда в свободной игре уже получена.'
              : 'Играй ещё! Награда за этот период уже получена.',
        CarRewardStatus.confirmedPreviously =>
          'Награда за эту игру уже сохранена.',
      };
    }
    return Container(
      key: const Key('car-reward-message'),
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
    required CarSession? session,
  }) {
    if (session != null && !isResult) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isResult)
            _GameButton(
              key: const Key('car-start'),
              label: 'Начать',
              onPressed: _startSession,
            )
          else ...[
            _GameButton(
              key: Key(
                _rewardError == null ? 'car-replay' : 'car-retry-reward',
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
              key: const Key('car-back-to-things'),
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
        key: const Key('car-room-background'),
        fit: BoxFit.cover,
      ),
      ColoredBox(color: AppColors.primaryLight.withValues(alpha: 0.18)),
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
      key: Key('car-finny-stage-$stage'),
      fit: BoxFit.contain,
      semanticLabel: '${pet?.name ?? 'Финни'} играет с машинкой',
    );
  }
}

/// Last panel of the existing three-toy production sheet, used where the
/// item itself is pictured. Gameplay uses a real overhead drawing below.
class _CarSprite extends StatelessWidget {
  const _CarSprite({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('car-production-art'),
    width: size,
    height: size,
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerRight,
        minWidth: size * 3,
        maxWidth: size * 3,
        minHeight: size,
        maxHeight: size,
        child: Image.asset(
          'assets/images/things/toys_sheet.png',
          width: size * 3,
          height: size,
          fit: BoxFit.fill,
          semanticLabel: 'Машинка',
        ),
      ),
    ),
  );
}

/// Deterministic overhead road: the same normalized center and boundaries
/// that the session uses for collision checks are used for painting.
class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.section});

  final CarTrackSection section;

  @override
  void paint(Canvas canvas, Size size) {
    final left = Path();
    final right = Path();
    final road = Path();
    const steps = 42;
    for (var i = 0; i <= steps; i++) {
      final y = size.height * i / steps;
      final progress = ((0.86 - y / size.height) / 0.66).clamp(0.0, 1.0);
      final center = section.centerAt(progress) * size.width;
      final leftX = center - section.halfWidth * size.width;
      final rightX = center + section.halfWidth * size.width;
      if (i == 0) {
        left.moveTo(leftX, y);
        right.moveTo(rightX, y);
        road.moveTo(leftX, y);
      } else {
        left.lineTo(leftX, y);
        right.lineTo(rightX, y);
        road.lineTo(leftX, y);
      }
    }
    for (var i = steps; i >= 0; i--) {
      final y = size.height * i / steps;
      final progress = ((0.86 - y / size.height) / 0.66).clamp(0.0, 1.0);
      final center = section.centerAt(progress) * size.width;
      road.lineTo(center + section.halfWidth * size.width, y);
    }
    road.close();
    canvas.drawPath(road, Paint()..color = const Color(0xFFB99CF3));
    for (final edge in [left, right]) {
      canvas.drawPath(
        edge,
        Paint()
          ..color = const Color(0xFF7756D9)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 20,
      );
      canvas.drawPath(
        edge,
        Paint()
          ..color = const Color(0xFFFFF5FF)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 12,
      );
    }
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.87)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final y1 = size.height * (i * 0.09);
      final y2 = y1 + size.height * 0.045;
      if (y1 >= size.height) break;
      final p1 = ((0.86 - y1 / size.height) / 0.66).clamp(0.0, 1.0);
      final p2 = ((0.86 - y2 / size.height) / 0.66).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(section.centerAt(p1) * size.width, y1),
        Offset(section.centerAt(p2) * size.width, y2),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) =>
      oldDelegate.section != section;
}

/// The production sprite is perspective art. This simple red toy silhouette
/// keeps the item recognizable while showing the steering position overhead.
class _TopDownCarPainter extends CustomPainter {
  const _TopDownCarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.03,
        size.width * 0.76,
        size.height * 0.94,
      ),
      Radius.circular(size.width * 0.26),
    );
    final wheelPaint = Paint()..color = const Color(0xFF392B65);
    for (final x in [0.02, 0.82]) {
      for (final y in [0.18, 0.68]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * x,
              size.height * y,
              size.width * 0.16,
              size.height * 0.18,
            ),
            const Radius.circular(5),
          ),
          wheelPaint,
        );
      }
    }
    canvas.drawRRect(body, Paint()..color = const Color(0xFFDA393B));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFFFF8F84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.22,
          size.height * 0.30,
          size.width * 0.56,
          size.height * 0.28,
        ),
        Radius.circular(size.width * 0.10),
      ),
      Paint()..color = const Color(0xFF534980),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.28,
          size.height * 0.35,
          size.width * 0.44,
          size.height * 0.18,
        ),
        Radius.circular(size.width * 0.07),
      ),
      Paint()..color = const Color(0xFF9DB8E6),
    );
    final light = Paint()..color = const Color(0xFFFFE59A);
    for (final x in [0.25, 0.69]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * 0.13),
        size.width * 0.06,
        light,
      );
    }
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.19),
      size.width * 0.07,
      Paint()..color = const Color(0xFFF7BEC9),
    );
  }

  @override
  bool shouldRepaint(covariant _TopDownCarPainter oldDelegate) => false;
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x220F0C69), blurRadius: 10)],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 20,
          vertical: small ? 8 : 10,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: small ? 13 : 18,
          ),
        ),
      ),
    ),
  );
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
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
