import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/budget/budget_controller.dart';
import 'package:finny/features/budget/budget_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  bool _confirmationOpen = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(budgetControllerProvider.notifier).load);
  }

  Future<void> _leave() async {
    final controller = ref.read(budgetControllerProvider.notifier);
    await controller.waitForPendingSaves();
    if (!mounted) return;
    final current = ref.read(budgetControllerProvider);
    if (current is BudgetReady &&
        (current.saveFailed || !current.draftIsPersisted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала сохрани изменение или повтори попытку.'),
        ),
      );
      return;
    }
    context.go('/home');
  }

  Future<void> _confirm() async {
    if (_confirmationOpen) return;
    _confirmationOpen = true;
    try {
      final controller = ref.read(budgetControllerProvider.notifier);
      final allocation = await controller.prepareConfirmation();
      if (!mounted || allocation == null) return;
      final current = ref.read(budgetControllerProvider);
      if (current is! BudgetReady || !current.canConfirm) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        barrierColor: const Color(0x880D0B39),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (context) => BudgetConfirmationSheet(
          allocation: allocation,
          total: current.period.startingBudget,
        ),
      );
      if (!mounted || confirmed != true) return;
      final succeeded = await controller.confirmPlan();
      if (mounted && succeeded) context.go('/home');
    } finally {
      _confirmationOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetControllerProvider);
    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      ref.read(budgetControllerProvider.notifier).load();
    });
    if (state is BudgetNeedsBootstrap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/startup');
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: switch (state) {
        BudgetLoading() || BudgetNeedsBootstrap() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        BudgetFailure() => _BudgetError(
          onBack: _leave,
          onRetry: ref.read(budgetControllerProvider.notifier).load,
        ),
        BudgetReady() => BudgetVisual(
          state: state,
          onBack: _leave,
          onConfirm: _confirm,
        ),
      },
    );
  }
}

class _BudgetError extends StatelessWidget {
  const _BudgetError({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: BackButton(onPressed: onBack)),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Не получилось открыть план дня.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
