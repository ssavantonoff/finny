import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/savings/savings_controller.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNestedNavigation extends ConsumerWidget {
  const ScaffoldWithNestedNavigation({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    if (index == 0) {
      ref.read(homeControllerProvider.notifier).load();
    } else if (index == 1) {
      ref.read(thingsControllerProvider.notifier).load();
    } else if (index == 2) {
      ref.read(shopControllerProvider.notifier).load();
    } else if (index == 4) {
      ref.read(savingsControllerProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(context, ref, index),
        destinations: const [
          NavigationDestination(
            key: Key('nav-home'),
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Финни',
          ),
          NavigationDestination(
            key: Key('nav-things'),
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack),
            label: 'Вещи',
          ),
          NavigationDestination(
            key: Key('nav-shop'),
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Магазин',
          ),
          NavigationDestination(
            key: Key('nav-tasks'),
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Задания',
          ),
          NavigationDestination(
            key: Key('nav-savings'),
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Накопления',
          ),
        ],
      ),
    );
  }
}
