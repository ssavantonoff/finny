import 'package:finny/app/bootstrap_screen.dart';
import 'package:finny/app/scaffold_with_nested_navigation.dart';
import 'package:finny/features/adult/adult_screen.dart';
import 'package:finny/features/budget/budget_screen.dart';
import 'package:finny/features/help/help_screen.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/features/onboarding/onboarding_screen.dart';
import 'package:finny/features/period_summary/period_summary_screen.dart';
import 'package:finny/features/pet_creation/pet_creation_screen.dart';
import 'package:finny/features/progress/progress_screen.dart';
import 'package:finny/features/savings/savings_screen.dart';
import 'package:finny/features/settings/settings_screen.dart';
import 'package:finny/features/shop/shop_screen.dart';
import 'package:finny/features/tasks/tasks_screen.dart';
import 'package:finny/features/things/things_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/startup'),
      GoRoute(path: '/startup', builder: (_, _) => const BootstrapScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/pet-creation',
        builder: (_, _) => const PetCreationScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNestedNavigation(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/things', builder: (_, _) => const ThingsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/tasks', builder: (_, _) => const TasksScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/savings',
                builder: (_, _) => const SavingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/budget', builder: (_, _) => const BudgetScreen()),
      GoRoute(
        path: '/period-summary',
        builder: (_, _) => const PeriodSummaryScreen(),
      ),
      GoRoute(
        path: '/progress',
        builder: (_, state) => ProgressScreen(
          completedDay: int.tryParse(state.uri.queryParameters['day'] ?? ''),
        ),
      ),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(path: '/adult', builder: (_, _) => const AdultScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
