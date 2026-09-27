import 'package:finny/app/bootstrap.dart';
import 'package:finny/app/bootstrap_screen.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/onboarding/profile_name.dart';
import 'package:finny/features/onboarding/welcome_visuals.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _nameController;
  final FocusNode _nameFocus = FocusNode();
  int _step = 0;
  bool _nameTouched = false;
  String? _scheduledDestination;

  void _navigate(BootstrapState state) {
    final destination = bootstrapDestination(state.phase);
    if (destination == null) {
      _scheduledDestination = null;
      return;
    }
    if (_scheduledDestination == destination) return;
    _scheduledDestination = destination;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && GoRouterState.of(context).uri.path != destination) {
        context.go(destination);
      }
    });
  }

  void _submit(BootstrapState state) {
    if (!ProfileName(_nameController.text).isValid) {
      setState(() => _nameTouched = true);
      return;
    }
    final controller = ref.read(bootstrapProvider.notifier);
    if (state.saveFailed) {
      controller.retryName(_nameController.text);
    } else {
      controller.submitName(_nameController.text);
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(bootstrapProvider).profile?.gameName ?? '',
    );
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && mounted && _step == 2) {
        setState(() => _nameTouched = true);
      }
    });
    if (ref.read(bootstrapProvider).phase == BootstrapPhase.loading) {
      Future.microtask(() {
        if (mounted) ref.read(bootstrapProvider.notifier).initialize();
      });
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapProvider);
    ref.listen<BootstrapState>(bootstrapProvider, (_, next) => _navigate(next));
    if (state.phase == BootstrapPhase.resolvedWithPet ||
        state.phase == BootstrapPhase.resolvedWithoutPet) {
      _navigate(state);
    }
    if (state.phase == BootstrapPhase.error ||
        state.phase == BootstrapPhase.profileConflict) {
      return const BootstrapErrorScreen();
    }
    if (state.phase != BootstrapPhase.onboardingNew &&
        state.phase != BootstrapPhase.onboardingExisting) {
      return const Scaffold(body: Center(child: FinnyBrand()));
    }
    final name = ProfileName(_nameController.text);
    return Scaffold(
      body: WelcomeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FinnyBrand(),
                      const SizedBox(height: 10),
                      WelcomeProgress(step: _step),
                      const SizedBox(height: 20),
                      if (_step == 0)
                        _intro()
                      else if (_step == 1)
                        _concepts()
                      else
                        _nameStep(state, name),
                      const SizedBox(height: 26),
                      WelcomeButton(
                        label: state.submitting
                            ? 'Сохраняем…'
                            : switch (_step) {
                                0 => 'Дальше',
                                1 => 'Понятно',
                                _ => 'Продолжить',
                              },
                        onPressed:
                            state.submitting || (_step == 2 && !name.isValid)
                            ? null
                            : () {
                                if (_step < 2) {
                                  setState(() => _step++);
                                } else {
                                  _submit(state);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro() => Column(
    children: [
      const FinnyPreview(colorId: 'purple', patternId: 'plain', height: 315),
      const SizedBox(height: 16),
      const Text(
        'Привет! Я Финни',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Здесь ты будешь помогать мне распоряжаться монетами, заботиться обо мне и копить на мечты.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );

  Widget _concepts() => Column(
    children: [
      const Text(
        'Давай познакомимся',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Три простые вещи помогут тебе принимать решения.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      const FinnyPreview(colorId: 'purple', patternId: 'plain', height: 100),
      const SizedBox(height: 8),
      _conceptCard(
        'Нужно',
        'То, без чего Финни трудно обойтись.',
        AppColors.need,
        Icons.restaurant_rounded,
      ),
      const SizedBox(height: 10),
      _conceptCard(
        'Хочу',
        'Приятные покупки, которые можно отложить.',
        AppColors.want,
        Icons.sports_baseball_rounded,
      ),
      const SizedBox(height: 10),
      _conceptCard(
        'Копилка',
        'Монеты, которые ты сохраняешь для будущей цели.',
        AppColors.savings,
        Icons.savings_rounded,
      ),
    ],
  );

  Widget _conceptCard(
    String title,
    String description,
    Color accent,
    IconData icon,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Color.lerp(Colors.white, accent, 0.09),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14716CD5),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 30, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _nameStep(BootstrapState state, ProfileName name) => Column(
    children: [
      const Text(
        'Как тебя зовут?',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 31,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Чтобы Финни знал, как к тебе обращаться.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 14),
      const FinnyPreview(colorId: 'purple', patternId: 'plain', height: 235),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C6C5CE7),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Твоё имя',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              enabled: !state.submitting,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: welcomeInputDecoration(
                hint: 'Например, Саша',
                error: _nameTouched ? name.error : null,
              ),
              onChanged: (value) => setState(() {
                if (value.trim().runes.length > 20) _nameTouched = true;
              }),
              onSubmitted: (_) => _submit(state),
            ),
            if (state.saveFailed) ...[
              const SizedBox(height: 10),
              const Text(
                'Не получилось сохранить игровой профиль. Попробуй ещё раз.',
                style: TextStyle(color: AppColors.error),
              ),
              TextButton(
                onPressed: name.isValid ? () => _submit(state) : null,
                child: const Text('Попробовать снова'),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
