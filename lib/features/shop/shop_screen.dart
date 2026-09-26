import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_art.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/features/shop/shop_item_details.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _ink = Color(0xFF1A2368);
const _muted = Color(0xFF7778A5);

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});
  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _scrollController = ScrollController();
  ShopDisplaySection _section = ShopDisplaySection.food;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(ref.read(shopControllerProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openPurchase(ShopItem item, ShopState state) {
    ref.read(shopControllerProvider.notifier).clearResult();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopItemDetails(item: item, profileId: state.profileId),
    );
  }

  void _listenForPurchaseSuccess(ShopState? previous, ShopState next) {
    if (next.result?.kind != ShopResultKind.success ||
        previous?.result?.kind == ShopResultKind.success) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Готово! Предмет куплен.'),
            duration: Duration(seconds: 2),
          ),
        );
      ref.read(shopControllerProvider.notifier).clearResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ShopState>(shopControllerProvider, _listenForPurchaseSuccess);
    final state = ref.watch(shopControllerProvider);
    final controller = ref.read(shopControllerProvider.notifier);
    final items = state.items
        .where((item) => item.displaySection == _section)
        .toList();
    final ready = state.load == ShopLoad.ready && state.items.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0FF),
      body: Stack(
        children: [
          const Positioned.fill(child: _ShopBackdrop()),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CustomScrollView(
                  key: const Key('shop-catalog'),
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
                        child: _ShopHeader(
                          balance: state.gameState?.walletBalance,
                          refreshing: state.purchasing,
                          onRefresh: controller.load,
                        ),
                      ),
                    ),
                    if (ready)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 58,
                          child: ListView.separated(
                            key: const Key('shop-category-navigation'),
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: ShopDisplaySection.values.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final section = ShopDisplaySection.values[index];
                              return _CategoryChip(
                                section: section,
                                selected: _section == section,
                                onTap: () {
                                  setState(() => _section = section);
                                  if (_scrollController.hasClients) {
                                    _scrollController.jumpTo(0);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    if (state.load == ShopLoad.loading)
                      _padded(
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (state.load != ShopLoad.ready) ...[
                      _padded(
                        ShopNotice(switch (state.load) {
                          ShopLoad.noProfile => 'Профиль пока не выбран.',
                          ShopLoad.contentError =>
                            'Не получилось открыть магазин. Попробуй ещё раз.',
                          _ =>
                            'Не получилось обновить магазин. Попробуй ещё раз.',
                        }),
                      ),
                      _padded(
                        FilledButton.tonal(
                          onPressed: state.purchasing ? null : controller.load,
                          child: const Text('Обновить'),
                        ),
                      ),
                    ] else ...[
                      if (state.items.isEmpty)
                        _padded(const Text('В магазине пока нет товаров.')),
                      if (state.period == null && !state.freePlay)
                        _padded(
                          const ShopNotice('Сначала начни игровой период.'),
                        )
                      else if (state.period?.status ==
                          GamePeriodStatus.planning)
                        _padded(const ShopNotice('Сначала подтверди план.')),
                      if (items.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          sliver: SliverGrid.builder(
                            key: const Key('shop-grid'),
                            itemCount: items.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 302,
                                ),
                            itemBuilder: (context, index) => _ShopProductCard(
                              item: items[index],
                              state: state,
                              onOpen: () => _openPurchase(items[index], state),
                            ),
                          ),
                        ),
                    ],
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            AppTheme.homeContentNavigationClearance +
                            MediaQuery.viewPaddingOf(context).bottom,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverPadding _padded(Widget child) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    sliver: SliverToBoxAdapter(child: child),
  );
}

class _ShopBackdrop extends StatelessWidget {
  const _ShopBackdrop();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7F5FF), Color(0xFFEAE8FF)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: 20,
          right: -8,
          child: Icon(
            Icons.storefront_rounded,
            size: 190,
            color: AppColors.primary.withValues(alpha: .07),
          ),
        ),
      ],
    ),
  );
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.balance,
    required this.refreshing,
    required this.onRefresh,
  });
  final int? balance;
  final bool refreshing;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Магазин',
              style: TextStyle(
                color: _ink,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: .86),
            borderRadius: BorderRadius.circular(20),
            child: IconButton(
              tooltip: 'Обновить магазин',
              onPressed: refreshing ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.primaryDark,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ),
        ],
      ),
      if (balance != null) ...[
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .86),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FinnyCatchArt(type: FinnyCatchObjectType.coin, size: 38),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$balance',
                      key: const Key('shop-wallet'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'Твои монеты',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ],
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.section,
    required this.selected,
    required this.onTap,
  });
  final ShopDisplaySection section;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      key: Key('shop-category-${section.name}'),
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFDAD7F4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_rounded
                  : switch (section) {
                      ShopDisplaySection.food => Icons.restaurant_rounded,
                      ShopDisplaySection.care => Icons.shower_rounded,
                      ShopDisplaySection.toys => Icons.sports_esports_rounded,
                      ShopDisplaySection.accessories =>
                        Icons.headphones_rounded,
                    },
              size: 20,
              color: selected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 7),
            Text(
              shopSectionLabel(section),
              style: TextStyle(
                color: selected ? Colors.white : _ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShopProductCard extends StatelessWidget {
  const _ShopProductCard({
    required this.item,
    required this.state,
    required this.onOpen,
  });
  final ShopItem item;
  final ShopState state;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final owned = item.persistent && (state.quantities[item.id] ?? 0) > 0;
    final discounted = state.isDiscountActiveFor(item);
    return DecoratedBox(
      key: discounted ? Key('shop-promo-card-${item.id}') : null,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .83),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E0A70),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        key: Key('shop-item-${item.id}'),
        borderRadius: BorderRadius.circular(28),
        onTap: owned ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 126,
                child: Stack(
                  children: [
                    Center(child: ShopItemArt(item: item)),
                    if (discounted)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          key: Key('shop-promo-marker-${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4FA8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'SALE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 40,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    height: 1.14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                shopCategory(item),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              ShopPriceLabel(item: item, state: state, fontSize: 17),
              const SizedBox(height: 7),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: Key('shop-card-buy-${item.id}'),
                  onPressed: owned ? null : onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE9E7F5),
                    disabledForegroundColor: _muted,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(owned ? 'Куплено' : 'Купить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
