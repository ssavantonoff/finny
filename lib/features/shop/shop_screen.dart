import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_item_details.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  static const _categoryBarHeight = 64.0;

  final _catalogController = ScrollController();
  final _catalogKey = GlobalKey();
  final _categoryBarKey = GlobalKey();
  final _sectionKeys = {
    for (final section in ShopDisplaySection.values) section: GlobalKey(),
  };

  ShopDisplaySection _activeSection = ShopDisplaySection.food;
  ShopDisplaySection? _programmaticSection;
  bool _activeUpdateScheduled = false;
  bool _promoEntranceScheduled = false;
  bool _promoVisible = false;

  @override
  void initState() {
    super.initState();
    _catalogController.addListener(_scheduleActiveSectionUpdate);
    Future.microtask(() {
      if (mounted) unawaited(ref.read(shopControllerProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _catalogController
      ..removeListener(_scheduleActiveSectionUpdate)
      ..dispose();
    super.dispose();
  }

  void _details(ShopItem item, ShopState state) {
    ref.read(shopControllerProvider.notifier).clearResult();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ShopItemDetails(item: item, profileId: state.profileId),
    );
  }

  void _scheduleActiveSectionUpdate() {
    if (_activeUpdateScheduled || !mounted) return;
    _activeUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeUpdateScheduled = false;
      _updateActiveSection();
    });
  }

  void _updateActiveSection() {
    if (!mounted ||
        !_catalogController.hasClients ||
        _programmaticSection != null) {
      return;
    }
    final available = _sectionKeys.entries
        .where((entry) => entry.value.currentContext != null)
        .toList(growable: false);
    if (available.isEmpty) return;

    var next = available.first.key;
    if (_catalogController.position.pixels >=
        _catalogController.position.maxScrollExtent - 1) {
      next = available.last.key;
    } else {
      final barBox = _categoryBarKey.currentContext?.findRenderObject();
      final threshold = barBox is RenderBox
          ? barBox.localToGlobal(Offset.zero).dy + barBox.size.height + 1
          : MediaQuery.paddingOf(context).top + _categoryBarHeight;
      for (final entry in available) {
        final renderObject = entry.value.currentContext!.findRenderObject();
        if (renderObject is! RenderBox) continue;
        if (renderObject.localToGlobal(Offset.zero).dy <= threshold) {
          next = entry.key;
        } else {
          break;
        }
      }
    }
    if (next != _activeSection) setState(() => _activeSection = next);
  }

  Future<void> _scrollToSection(ShopDisplaySection section) async {
    final sectionBox = _sectionKeys[section]?.currentContext
        ?.findRenderObject();
    final catalogBox = _catalogKey.currentContext?.findRenderObject();
    if (sectionBox is! RenderBox ||
        catalogBox is! RenderBox ||
        !_catalogController.hasClients) {
      return;
    }
    _programmaticSection = section;
    setState(() => _activeSection = section);
    final sectionY = sectionBox.localToGlobal(Offset.zero).dy;
    final catalogY = catalogBox.localToGlobal(Offset.zero).dy;
    final target =
        (_catalogController.offset + sectionY - catalogY - _categoryBarHeight)
            .clamp(
              _catalogController.position.minScrollExtent,
              _catalogController.position.maxScrollExtent,
            );
    await _catalogController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    if (mounted && _activeSection != section) {
      setState(() => _activeSection = section);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticSection = null;
    });
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
    final readyWithItems =
        state.load == ShopLoad.ready && state.items.isNotEmpty;
    final promoItem = state.items.where(state.isPromotionActiveFor).firstOrNull;
    if (promoItem != null && !_promoEntranceScheduled) {
      _promoEntranceScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _promoVisible = true);
      });
    }
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин'),
        actions: [
          IconButton(
            tooltip: 'Обновить магазин',
            onPressed: state.purchasing ? null : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: CustomScrollView(
              key: _catalogKey,
              controller: _catalogController,
              slivers: [
                if (state.gameState != null)
                  _padded(
                    Text(
                      'У тебя: ${state.gameState!.walletBalance} монет',
                      key: const Key('shop-wallet'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    top: AppSpacing.medium,
                  ),
                if (promoItem != null)
                  _padded(
                    AnimatedOpacity(
                      opacity: _promoVisible || disableAnimations ? 1 : 0,
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      child: AnimatedScale(
                        scale: _promoVisible || disableAnimations ? 1 : .96,
                        duration: disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        child: _PromotionBanner(item: promoItem, state: state),
                      ),
                    ),
                    top: AppSpacing.small,
                  ),
                if (state.purchasing ||
                    (state.result != null &&
                        state.result!.kind != ShopResultKind.success))
                  _padded(ShopPurchaseNotice(state: state)),
                if (readyWithItems)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryHeaderDelegate(
                      height: _categoryBarHeight,
                      active: _activeSection,
                      barKey: _categoryBarKey,
                      onSelected: _scrollToSection,
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
                      _ => 'Не получилось обновить магазин. Попробуй ещё раз.',
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
                    _padded(const ShopNotice('Сначала начни игровой период.'))
                  else if (state.period?.status == GamePeriodStatus.planning)
                    _padded(const ShopNotice('Сначала подтверди план.')),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        for (final section in ShopDisplaySection.values)
                          if (state.items.any(
                            (item) => item.displaySection == section,
                          ))
                            _ShopSection(
                              key: _sectionKeys[section],
                              section: section,
                              items: state.items
                                  .where(
                                    (item) => item.displaySection == section,
                                  )
                                  .toList(growable: false),
                              state: state,
                              onItemTap: _details,
                            ),
                      ],
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.large),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverPadding _padded(Widget child, {double top = 0}) => SliverPadding(
    padding: EdgeInsets.fromLTRB(AppSpacing.medium, top, AppSpacing.medium, 0),
    sliver: SliverToBoxAdapter(child: child),
  );
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner({required this.item, required this.state});

  final ShopItem item;
  final ShopState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Акция дня. ${item.name}: было ${item.price} монет, сейчас ${state.effectivePriceFor(item)}.',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('shop-promo-banner'),
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: colors.tertiary),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: colors.onTertiaryContainer,
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Акция дня',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${item.name} · ${item.price} → ${state.effectivePriceFor(item)} монет',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: colors.onTertiaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CategoryHeaderDelegate({
    required this.height,
    required this.active,
    required this.barKey,
    required this.onSelected,
  });

  final double height;
  final ShopDisplaySection active;
  final GlobalKey barKey;
  final ValueChanged<ShopDisplaySection> onSelected;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    key: barKey,
    color: Theme.of(context).scaffoldBackgroundColor,
    elevation: overlapsContent ? 2 : 0,
    child: SingleChildScrollView(
      key: const Key('shop-category-navigation'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      child: Row(
        children: [
          for (final section in ShopDisplaySection.values) ...[
            ChoiceChip(
              key: Key('shop-category-${section.name}'),
              label: Text(shopSectionLabel(section)),
              selected: active == section,
              showCheckmark: true,
              onSelected: (_) => onSelected(section),
            ),
            if (section != ShopDisplaySection.values.last)
              const SizedBox(width: AppSpacing.small),
          ],
        ],
      ),
    ),
  );

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) =>
      active != oldDelegate.active || height != oldDelegate.height;
}

class _ShopSection extends StatelessWidget {
  const _ShopSection({
    super.key,
    required this.section,
    required this.items,
    required this.state,
    required this.onItemTap,
  });

  final ShopDisplaySection section;
  final List<ShopItem> items;
  final ShopState state;
  final void Function(ShopItem item, ShopState state) onItemTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.medium,
      AppSpacing.medium,
      AppSpacing.medium,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          shopSectionLabel(section),
          key: Key('shop-section-${section.name}'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final item in items)
          Card(
            key: state.isDiscountActiveFor(item)
                ? Key('shop-promo-card-${item.id}')
                : null,
            color: state.isDiscountActiveFor(item)
                ? Theme.of(context).colorScheme.tertiaryContainer
                      .withValues(alpha: .4)
                : null,
            shape: state.isDiscountActiveFor(item)
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.tertiary,
                      width: 1.5,
                    ),
                  )
                : null,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('shop-item-${item.id}'),
              onTap: item.persistent && (state.quantities[item.id] ?? 0) > 0
                  ? null
                  : () => onItemTap(item, state),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ShopItemIcon(item: item),
                        const SizedBox(width: AppSpacing.medium),
                        Expanded(
                          child: Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.small),
                    if (state.isDiscountActiveFor(item)) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          key: Key('shop-promo-marker-${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.small,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            state.isDayFiveSaleDay ? 'Распродажа' : 'Акция дня',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                    ],
                    ShopPriceLabel(item: item, state: state, fontSize: 16),
                    if (shopEffect(item) case final effect?)
                      Text(effect, style: const TextStyle(fontSize: 16)),
                    if (item.persistent && (state.quantities[item.id] ?? 0) > 0)
                      const Text('✓ Куплено', style: TextStyle(fontSize: 16))
                    else if (item.unlockType != 'available')
                      const Text('Этот предмет пока недоступен.'),
                    const SizedBox(height: AppSpacing.small),
                    const Text(
                      'Посмотреть',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
