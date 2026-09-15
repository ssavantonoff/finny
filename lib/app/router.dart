import 'package:finny/features/adult/adult_screen.dart';
import 'package:finny/features/budget/budget_screen.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/features/onboarding/onboarding_screen.dart';
import 'package:finny/features/period_summary/period_summary_screen.dart';
import 'package:finny/features/pet_creation/pet_creation_screen.dart';
import 'package:finny/features/progress/progress_screen.dart';
import 'package:finny/features/savings/savings_screen.dart';
import 'package:finny/features/settings/settings_screen.dart';
import 'package:finny/features/shop/shop_screen.dart';
import 'package:finny/features/tasks/tasks_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/onboarding'),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/pet-creation',
        builder: (_, _) => const PetCreationScreen(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/budget', builder: (_, _) => const BudgetScreen()),
      GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
      GoRoute(path: '/savings', builder: (_, _) => const SavingsScreen()),
      GoRoute(path: '/tasks', builder: (_, _) => const TasksScreen()),
      GoRoute(
        path: '/period-summary',
        builder: (_, _) => const PeriodSummaryScreen(),
      ),
      GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
      GoRoute(path: '/adult', builder: (_, _) => const AdultScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
