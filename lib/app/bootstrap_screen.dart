import 'package:finny/app/bootstrap.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String? bootstrapDestination(BootstrapPhase phase) => switch (phase) {
  BootstrapPhase.onboardingNew ||
  BootstrapPhase.onboardingExisting => '/onboarding',
  BootstrapPhase.resolvedWithoutPet => '/pet-creation',
  BootstrapPhase.resolvedWithPet => '/home',
  _ => null,
};

class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  String? _scheduledDestination;

  void _navigate(BootstrapState state) {
    final destination = state.destination ?? bootstrapDestination(state.phase);
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(bootstrapProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapProvider);
    ref.listen<BootstrapState>(bootstrapProvider, (_, next) => _navigate(next));
    return switch (state.phase) {
      BootstrapPhase.error ||
      BootstrapPhase.profileConflict => const BootstrapErrorScreen(),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class BootstrapErrorScreen extends ConsumerWidget {
  const BootstrapErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Не получилось открыть игровой профиль.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton(
                onPressed: () =>
                    ref.read(bootstrapProvider.notifier).initialize(),
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
