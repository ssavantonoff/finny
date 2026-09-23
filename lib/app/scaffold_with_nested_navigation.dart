import 'dart:async';

import 'package:finny/features/home/campaign_event_controller.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/savings/savings_controller.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNestedNavigation extends ConsumerStatefulWidget {
  const ScaffoldWithNestedNavigation({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNestedNavigation> createState() =>
      _ScaffoldWithNestedNavigationState();
}

class _ScaffoldWithNestedNavigationState
    extends ConsumerState<ScaffoldWithNestedNavigation> {
  int? _lastHomePeriodId;
  bool _hasSeenHomePeriod = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(shopControllerProvider.notifier).load());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScaffoldWithNestedNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex != 0 &&
        widget.navigationShell.currentIndex == 0) {
      unawaited(ref.read(campaignEventControllerProvider.notifier).load());
    }
  }

  void _onHomeState(HomeViewState? previous, HomeViewState next) {
    if (next is! HomeReady) return;
    final periodId = next.period?.id;
    if (!_hasSeenHomePeriod || periodId != _lastHomePeriodId) {
      _hasSeenHomePeriod = true;
      _lastHomePeriodId = periodId;
      unawaited(ref.read(shopControllerProvider.notifier).load());
    }
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    if (index == 0) {
      ref.read(homeControllerProvider.notifier).load();
      unawaited(ref.read(campaignEventControllerProvider.notifier).load());
      unawaited(ref.read(shopControllerProvider.notifier).load());
    } else if (index == 1) {
      ref.read(thingsControllerProvider.notifier).load();
    } else if (index == 2) {
      ref.read(shopControllerProvider.notifier).load();
    } else if (index == 4) {
      ref.read(savingsControllerProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HomeViewState>(homeControllerProvider, _onHomeState);
    final shop = ref.watch(shopControllerProvider);
    final treat = shop.itemById('food_treat');
    final showShopPromotion =
        shop.load == ShopLoad.ready &&
        (shop.isDayFiveSaleDay ||
            (treat != null && shop.isPromotionActiveFor(treat)));
    final badgeText = shop.isDayFiveSaleDay ? 'SALE' : 'АКЦИЯ';
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(context, ref, index),
        destinations: [
          const NavigationDestination(
            key: Key('nav-home'),
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Финни',
          ),
          const NavigationDestination(
            key: Key('nav-things'),
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack),
            label: 'Вещи',
          ),
          NavigationDestination(
            key: const Key('nav-shop'),
            icon: _ShopNavigationIcon(
              showPromotion: showShopPromotion,
              badgeText: badgeText,
            ),
            selectedIcon: _ShopNavigationIcon(
              showPromotion: showShopPromotion,
              badgeText: badgeText,
              selected: true,
            ),
            label: 'Магазин',
          ),
          const NavigationDestination(
            key: Key('nav-tasks'),
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Задания',
          ),
          const NavigationDestination(
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

class _ShopNavigationIcon extends StatelessWidget {
  const _ShopNavigationIcon({
    required this.showPromotion,
    required this.badgeText,
    this.selected = false,
  });

  final bool showPromotion;
  final String badgeText;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? Icons.storefront : Icons.storefront_outlined);
    if (!showPromotion) return icon;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        icon,
        Positioned(
          top: -14,
          child: Semantics(
            label: badgeText == 'SALE'
                ? 'В магазине распродажа'
                : 'В магазине действует акция',
            child: ExcludeSemantics(
              child: DecoratedBox(
                key: const Key('nav-shop-promo-badge'),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
