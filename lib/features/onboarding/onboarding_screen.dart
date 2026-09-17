import 'package:finny/app/bootstrap.dart';
import 'package:finny/app/bootstrap_screen.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/onboarding/profile_name.dart';
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
  int _step = 0;
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
    if (ref.read(bootstrapProvider).phase == BootstrapPhase.loading) {
      Future.microtask(() {
        if (mounted) ref.read(bootstrapProvider.notifier).initialize();
      });
    }
  }

  @override
  void dispose() {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = ProfileName(_nameController.text);
    final title = switch (_step) {
      0 => 'Привет! Я Финни',
      1 => 'Давай познакомимся',
      _ => 'Как тебя называть?',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Finny')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Шаг ${_step + 1} из 3'),
                  const SizedBox(height: AppSpacing.medium),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.large),
                  if (_step == 0)
                    const Text(
                      'Здесь ты будешь помогать Финни распоряжаться монетами, заботиться о нём и копить на мечты.',
                      style: TextStyle(fontSize: 16),
                    )
                  else if (_step == 1)
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Нужно — то, без чего Финни трудно обойтись.',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: AppSpacing.medium),
                        Text(
                          'Хочется — приятные покупки.',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: AppSpacing.medium),
                        Text(
                          'Копилка — деньги на будущую цель.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    )
                  else ...[
                    TextField(
                      controller: _nameController,
                      enabled: !state.submitting,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Игровое имя',
                        border: const OutlineInputBorder(),
                        errorText: name.error,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (state.saveFailed) ...[
                      const SizedBox(height: AppSpacing.medium),
                      const Text(
                        'Не получилось сохранить игровой профиль. Попробуй ещё раз.',
                      ),
                      TextButton(
                        onPressed: name.isValid ? () => _submit(state) : null,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.extraLarge),
                  FilledButton(
                    onPressed: state.submitting || (_step == 2 && !name.isValid)
                        ? null
                        : () {
                            if (_step < 2) {
                              setState(() => _step++);
                            } else {
                              _submit(state);
                            }
                          },
                    child: Text(
                      state.submitting
                          ? 'Сохраняем…'
                          : _step == 0
                          ? 'Дальше'
                          : _step == 1
                          ? 'Понятно'
                          : 'Продолжить',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
