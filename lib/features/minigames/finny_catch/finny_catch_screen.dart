import 'dart:math' as math;

import 'package:finny/app/providers.dart';
import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'finny_catch_art.dart';
import 'finny_catch_controller.dart';
import 'finny_catch_models.dart';

class FinnyCatchScreen extends ConsumerStatefulWidget {
  const FinnyCatchScreen({super.key, this.controller});

  final FinnyCatchController? controller;

  @override
  ConsumerState<FinnyCatchScreen> createState() => _FinnyCatchScreenState();
}

class _FinnyCatchScreenState extends ConsumerState<FinnyCatchScreen>
    with WidgetsBindingObserver {
  static const _backgroundAsset =
      'assets/minigames/finny_catch/background_mountains.png';

  late final FinnyCatchController _controller;
  late final bool _ownsController;
  bool _exitDialogOpen = false;
  Pet? _pet;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        FinnyCatchController(
          profileId: ref.read(activeProfileIdProvider)!,
          grantReward: ref.read(freePlayServiceProvider).grantMinigameReward,
        );
    WidgetsBinding.instance.addObserver(this);
    _loadPet();
  }

  Future<void> _loadPet() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    try {
      final pet = await ref.read(gameRepositoryProvider).getPet(profileId);
      if (mounted && ref.read(activeProfileIdProvider) == profileId) {
        setState(() => _pet = pet);
      }
    } catch (_) {
      // Gameplay remains usable if reading the appearance fails.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.abort();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    _controller.abort();
    await ref.read(homeControllerProvider.notifier).load();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _handleBack() async {
    if (_exitDialogOpen) return;
    final state = _controller.state;
    if (state.phase == FinnyCatchPhase.prepare) {
      await _goHome();
      return;
    }
    if (state.phase == FinnyCatchPhase.result) {
      if (state.rewardGranted) {
        await _goHome();
      } else if (!state.savingReward) {
        await _confirmUnsavedReward();
      }
      return;
    }
    _controller.pause();
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из игры?'),
        content: const Text('Награда за этот раунд не сохранится.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted) return;
    if (leave == true) {
      await _goHome();
    } else {
      _controller.resume();
    }
  }

  Future<void> _confirmUnsavedReward() async {
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Награда не сохранена'),
        content: const Text(
          'Если выйти сейчас, монеты за этот раунд пропадут.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Повторить сохранение'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти без награды'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted) return;
    if (leave == true) {
      await _goHome();
    } else {
      await _controller.retryReward();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final state = _controller.state;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _backgroundAsset,
                key: const Key('finny-catch-background'),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
              SafeArea(
                child: Column(
                  children: [
                    _header(state),
                    Expanded(child: _field(state)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _header(FinnyCatchState state) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    decoration: const BoxDecoration(
      color: Color(0xCCF9F8FF),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Лови монеты',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF282777),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: 'Назад',
                  child: IconButton.filledTonal(
                    tooltip: 'Назад',
                    onPressed: _handleBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 30),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F0FF),
                      foregroundColor: const Color(0xFF6541DC),
                      minimumSize: const Size(52, 52),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _HudPill(
                icon: const FinnyCatchArt(
                  type: FinnyCatchObjectType.sparkle,
                  size: 38,
                ),
                label: 'Очки',
                value: '${state.score}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HudPill(
                icon: const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFF6242DC),
                  size: 38,
                ),
                label: '',
                value: '${state.remainingSeconds} сек',
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _field(FinnyCatchState state) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      _controller.setFieldWidth(width);
      final finnyWidth = _controller.finnyVisualWidth;
      final objectSize = math.min(72.0, width / 5 * 0.9);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            _controller.moveFinny(details.localPosition.dx / width),
        onPanDown: (details) =>
            _controller.moveFinny(details.localPosition.dx / width),
        onPanUpdate: (details) =>
            _controller.moveFinny(details.localPosition.dx / width),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              bottom: -65,
              left: -width * 0.1,
              right: -width * 0.1,
              height: 130,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F4FF).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(1000),
                ),
              ),
            ),
            if (state.phase == FinnyCatchPhase.result) ...[
              Positioned(
                left: width * 0.1,
                top: height * 0.09,
                child: FinnyCatchArt(
                  type: FinnyCatchObjectType.coin,
                  size: objectSize,
                ),
              ),
              Positioned(
                right: width * 0.1,
                top: height * 0.21,
                child: FinnyCatchArt(
                  type: FinnyCatchObjectType.sparkle,
                  size: objectSize,
                ),
              ),
            ],
            for (final falling in state.objects)
              Positioned(
                left: falling.object.x * width - objectSize / 2,
                top:
                    -objectSize +
                    falling.progress *
                        (height - finnyWidth * 0.75 + objectSize),
                child: IgnorePointer(
                  child: FinnyCatchArt(
                    type: falling.object.type,
                    size: objectSize,
                  ),
                ),
              ),
            if (_pet != null)
              Positioned(
                left: state.finnyX * width - finnyWidth / 2,
                bottom: 6,
                width: finnyWidth,
                child: Semantics(
                  image: true,
                  label:
                      '${FinnyVisual.descriptionForPet(_pet!)}, перетаскивай его пальцем',
                  child: Image.asset(
                    FinnyVisual.assetForPet(_pet!),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            if (state.phase == FinnyCatchPhase.prepare)
              _centeredCard(height, _prepareCard()),
            if (state.phase == FinnyCatchPhase.countdown)
              Center(
                child: Text(
                  state.countdownText!,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5639CC),
                    shadows: [Shadow(color: Color(0x99FFFFFF), blurRadius: 20)],
                  ),
                ),
              ),
            if (state.phase == FinnyCatchPhase.paused)
              _centeredCard(height, _pauseCard()),
            if (state.phase == FinnyCatchPhase.result)
              _centeredCard(height, _resultCard(state)),
          ],
        ),
      );
    },
  );

  Widget _centeredCard(double fieldHeight, Widget card) => Align(
    alignment: const Alignment(0, -0.27),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 330, maxHeight: fieldHeight * 0.72),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: card,
      ),
    ),
  );

  Widget _cardShell(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    decoration: BoxDecoration(
      color: const Color(0xFFFDFBFF),
      borderRadius: BorderRadius.circular(34),
      boxShadow: const [
        BoxShadow(
          color: Color(0x333F2B97),
          blurRadius: 26,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );

  Widget _prepareCard() => _cardShell([
    const Text('Приготовься!', textAlign: TextAlign.center, style: _titleStyle),
    const SizedBox(height: 12),
    const Text(
      'Двигай Финни пальцем\nи лови полезные предметы',
      textAlign: TextAlign.center,
      style: _subtitleStyle,
    ),
    const SizedBox(height: 22),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _LegendItem(FinnyCatchObjectType.coin, '+1'),
        _LegendItem(FinnyCatchObjectType.sparkle, '+3'),
        _LegendItem(FinnyCatchObjectType.cloud, 'Избегай'),
      ],
    ),
    const SizedBox(height: 24),
    _GameButton(label: 'Начать игру', onPressed: _controller.start),
  ]);

  Widget _pauseCard() => _cardShell([
    const Text('Пауза', style: _titleStyle),
    const SizedBox(height: 14),
    const Text('Игра остановлена.', style: _subtitleStyle),
    const SizedBox(height: 22),
    _GameButton(label: 'Продолжить', onPressed: _controller.resume),
    const SizedBox(height: 10),
    _GameButton(label: 'Выйти', onPressed: _handleBack, light: true),
  ]);

  Widget _resultCard(FinnyCatchState state) => _cardShell([
    const Text('Отличная игра!', style: _titleStyle),
    const SizedBox(height: 14),
    Text(
      '${state.score}',
      style: const TextStyle(
        fontSize: 64,
        height: 1,
        fontWeight: FontWeight.w900,
        color: Color(0xFF2B287E),
      ),
    ),
    const Text('очка', style: _subtitleStyle),
    const SizedBox(height: 14),
    const Text('Награда', style: _subtitleStyle),
    const SizedBox(height: 4),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const FinnyCatchArt(type: FinnyCatchObjectType.coin, size: 54),
        const SizedBox(width: 8),
        Text(
          '+${state.rewardAmount}',
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Color(0xFF5534D3),
          ),
        ),
      ],
    ),
    if (state.savingReward)
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Сохраняем награду…'),
      ),
    if (state.rewardError != null) ...[
      const SizedBox(height: 8),
      Text(
        state.rewardError!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFA52455)),
      ),
      TextButton(
        onPressed: _controller.retryReward,
        child: const Text('Повторить сохранение'),
      ),
    ],
    const SizedBox(height: 18),
    _GameButton(
      label: 'Сыграть ещё',
      onPressed: state.rewardGranted ? _controller.replay : null,
    ),
    const SizedBox(height: 10),
    _GameButton(
      label: 'Вернуться к Финни',
      onPressed: state.rewardGranted ? _goHome : _handleBack,
      light: true,
    ),
  ]);

  static const _titleStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: Color(0xFF292678),
  );
  static const _subtitleStyle = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: Color(0xFF6F7090),
  );
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.label,
    required this.value,
  });
  final Widget icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xE8FFFFFF),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 5),
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(color: Color(0xFF6F7090))),
        if (label.isNotEmpty) const SizedBox(width: 5),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF292678),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.type, this.label);
  final FinnyCatchObjectType type;
  final String label;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FinnyCatchArt(type: type, size: 58),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: type == FinnyCatchObjectType.cloud
                ? const Color(0xFFC43B63)
                : const Color(0xFF5639CC),
          ),
        ),
      ],
    ),
  );
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.label,
    required this.onPressed,
    this.light = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Ink(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: light
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF8B6AF6), Color(0xFF5939E2)],
                  ),
            color: light ? const Color(0xFFF4F1FF) : null,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color(0x335C3CD6),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: onPressed == null
                    ? const Color(0xFF9F9CB7)
                    : light
                    ? const Color(0xFF292678)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
