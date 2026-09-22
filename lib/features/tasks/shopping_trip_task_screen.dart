import 'dart:math';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';

enum _ShoppingStage { intro, shelf, checkout, success }

class ShoppingTripTaskScreen extends StatefulWidget {
  const ShoppingTripTaskScreen({
    super.key,
    required this.task,
    required this.controller,
    this.random,
  });

  final FinancialTask task;
  final TasksController controller;
  final Random? random;

  @override
  State<ShoppingTripTaskScreen> createState() => _ShoppingTripTaskScreenState();
}

class _ShoppingTripTaskScreenState extends State<ShoppingTripTaskScreen> {
  final _selections = <String, ShoppingTripSelection>{};
  final _smallOnLeft = <String, bool>{};
  _ShoppingStage _stage = _ShoppingStage.intro;
  int _shelf = 0;
  TaskShoppingTripIncorrect? _incorrect;
  bool _submitting = false;
  bool _runtimeError = false;

  ShoppingTripTaskScenario get _scenario => widget.task.shoppingTripScenario;
  int get _packageCount => _selections.values.fold(
    0,
    (count, item) => count + item.smallQuantity + item.largeQuantity,
  );
  String get _packageCountLabel {
    final lastTwo = _packageCount % 100;
    if (lastTwo >= 11 && lastTwo <= 14) return '$_packageCount товаров';
    return switch (_packageCount % 10) {
      1 => '$_packageCount товар',
      2 || 3 || 4 => '$_packageCount товара',
      _ => '$_packageCount товаров',
    };
  }

  int get _total => _scenario.evaluate(_selections).totalCost;

  TextStyle _type(
    TextStyle? base, {
    required double size,
    FontWeight weight = FontWeight.w500,
  }) => (base ?? const TextStyle()).copyWith(
    fontSize: size,
    fontWeight: weight,
    height: 1.35,
  );

  @override
  void initState() {
    super.initState();
    final random = widget.random ?? Random();
    for (final item in _scenario.items) {
      final scenario =
          item.priceScenarios[random.nextInt(item.priceScenarios.length)];
      _selections[item.id] = ShoppingTripSelection(
        priceScenarioId: scenario.id,
        smallQuantity: 0,
        largeQuantity: 0,
      );
      _smallOnLeft[item.id] = random.nextBool();
    }
  }

  void _quantity(ShoppingTripItem item, bool small, int delta) {
    if (_submitting || _stage == _ShoppingStage.success) return;
    final before = _selections[item.id]!;
    final package = small ? item.smallPackage : item.largePackage;
    final current = small ? before.smallQuantity : before.largeQuantity;
    final next = current + delta;
    if (next < 0 || next > package.maxQuantity) return;
    setState(() {
      _selections[item.id] = ShoppingTripSelection(
        priceScenarioId: before.priceScenarioId,
        smallQuantity: small ? next : before.smallQuantity,
        largeQuantity: small ? before.largeQuantity : next,
      );
      _incorrect = null;
      _runtimeError = false;
    });
  }

  Future<void> _requestExit() async {
    if (_submitting) return;
    if (_stage == _ShoppingStage.success || _packageCount == 0) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из магазина?'),
        content: const Text('Корзина очистится.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _check() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _runtimeError = false;
    });
    try {
      final result = await widget.controller.submitShoppingTrip(
        widget.task,
        Map.unmodifiable(_selections),
      );
      if (!mounted) return;
      setState(() {
        if (result is TaskAnswerCompleted) {
          _stage = _ShoppingStage.success;
          _incorrect = null;
        } else if (result is TaskShoppingTripIncorrect) {
          _incorrect = result;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _runtimeError = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _amount(ShoppingTripItem item, int amount) => switch (item.unit) {
    'ml' =>
      amount % 1000 == 0
          ? '${amount ~/ 1000} л'
          : '${(amount / 1000).toStringAsFixed(1).replaceAll('.', ',')} л',
    'pcs' => '$amount шт.',
    'g' => '$amount г',
    _ => '$amount ${item.unit}',
  };

  int _itemAmount(ShoppingTripItem item) {
    final selection = _selections[item.id]!;
    return selection.smallQuantity * item.smallPackage.amount +
        selection.largeQuantity * item.largePackage.amount;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestExit();
    },
    child: Scaffold(
      key: const Key('shopping-trip-screen'),
      appBar: AppBar(
        title: Text(widget.task.title),
        leading: IconButton(
          tooltip: 'Закрыть',
          onPressed: _submitting ? null : _requestExit,
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _ShoppingStage.intro => _intro(context),
          _ShoppingStage.shelf => _shelfView(context),
          _ShoppingStage.checkout => _checkout(context),
          _ShoppingStage.success => _success(context),
        },
      ),
      bottomNavigationBar: _stage == _ShoppingStage.shelf
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  0,
                  AppSpacing.medium,
                  AppSpacing.small,
                ),
                child: _ShoppingCartDock(
                  packageCount: _packageCount,
                  packageCountLabel: _packageCountLabel,
                  total: _total,
                  budget: _scenario.budget,
                  onTap: _showCart,
                ),
              ),
            )
          : null,
    ),
  );

  Widget _intro(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.medium),
    children: [
      Text(
        widget.task.title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.medium),
      Text(
        _scenario.prompt,
        style: _type(
          Theme.of(context).textTheme.titleMedium,
          size: 18,
          weight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: AppSpacing.medium),
      for (final item in _scenario.items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.small),
          child: Text(
            '${item.label} — не меньше ${item.requirementLabel}',
            style: _type(Theme.of(context).textTheme.bodyLarge, size: 18),
          ),
        ),
      const SizedBox(height: AppSpacing.large),
      FilledButton(
        key: const Key('shopping-enter'),
        onPressed: () => setState(() => _stage = _ShoppingStage.shelf),
        child: Text(
          'В магазин',
          style: _type(null, size: 16, weight: FontWeight.w700),
        ),
      ),
    ],
  );

  Widget _shelfView(BuildContext context) {
    final item = _scenario.items[_shelf];
    final selection = _selections[item.id]!;
    final prices = item.scenarioById(selection.priceScenarioId);
    final smallLeft = _smallOnLeft[item.id]!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              Text(
                '${_shelf + 1} из ${_scenario.items.length} · ${item.label}',
                key: const Key('shopping-shelf-header'),
                style: _type(
                  Theme.of(context).textTheme.headlineSmall,
                  size: 23,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                'Нужно: не меньше ${item.requirementLabel}',
                key: const Key('shopping-requirement'),
                style: _type(
                  Theme.of(context).textTheme.titleMedium,
                  size: 18,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                'Бюджет: ${_scenario.budget} 🪙',
                style: _type(
                  Theme.of(context).textTheme.titleMedium,
                  size: 18,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 8,
                            offset: Offset(0, 4),
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _product(item, smallLeft, prices)),
                        Expanded(child: _product(item, !smallLeft, prices)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  if (_shelf > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _shelf--),
                        child: Text(
                          '← Назад',
                          style: _type(null, size: 16, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (_shelf > 0) const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: FilledButton(
                      key: const Key('shopping-next'),
                      onPressed: () => setState(() {
                        if (_shelf < _scenario.items.length - 1) {
                          _shelf++;
                        } else {
                          _stage = _ShoppingStage.checkout;
                        }
                      }),
                      child: Text(
                        _shelf < _scenario.items.length - 1
                            ? 'Следующая полка →'
                            : 'К кассе',
                        style: _type(null, size: 16, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _product(
    ShoppingTripItem item,
    bool small,
    ShoppingTripPriceScenario prices,
  ) {
    final package = small ? item.smallPackage : item.largePackage;
    final quantity = small
        ? _selections[item.id]!.smallQuantity
        : _selections[item.id]!.largeQuantity;
    final price = small ? prices.smallPrice : prices.largePrice;
    return Semantics(
      label:
          '${item.label} ${package.label}, $price монет, количество $quantity',
      child: Column(
        children: [
          SizedBox(
            height: 166,
            child: Center(
              child: CustomPaint(
                key: Key('shopping-product-${item.id}-${package.id}'),
                size: const Size(125, 155),
                painter: _ProductPainter(
                  itemId: item.id,
                  large: !small,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          Text(
            package.label,
            style: _type(
              Theme.of(context).textTheme.titleMedium,
              size: 18,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            '$price 🪙',
            key: Key('shopping-product-price-${item.id}-${package.id}'),
            style: _type(
              Theme.of(context).textTheme.titleMedium,
              size: 20,
              weight: FontWeight.w700,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: Key('shopping-minus-${item.id}-${package.id}'),
                tooltip: 'Убрать ${package.label}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                iconSize: 28,
                onPressed: quantity == 0
                    ? null
                    : () => _quantity(item, small, -1),
                icon: const Icon(Icons.remove),
              ),
              Text(
                '$quantity',
                key: Key('shopping-quantity-${item.id}-${package.id}'),
                style: _type(
                  Theme.of(context).textTheme.titleMedium,
                  size: 20,
                  weight: FontWeight.w700,
                ),
              ),
              IconButton(
                key: Key('shopping-plus-${item.id}-${package.id}'),
                tooltip: 'Добавить ${package.label}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                iconSize: 28,
                onPressed: quantity == package.maxQuantity
                    ? null
                    : () => _quantity(item, small, 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) => Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Корзина',
                  style: _type(
                    Theme.of(context).textTheme.titleLarge,
                    size: 22,
                    weight: FontWeight.w700,
                  ),
                ),
                if (_packageCount == 0)
                  Text(
                    'Корзина пока пуста.',
                    style: _type(
                      Theme.of(context).textTheme.bodyLarge,
                      size: 17,
                    ),
                  ),
                for (final item in _scenario.items) ...[
                  if (_selections[item.id]!.smallQuantity > 0 ||
                      _selections[item.id]!.largeQuantity > 0)
                    Text(
                      item.label,
                      style: _type(
                        Theme.of(context).textTheme.titleMedium,
                        size: 18,
                        weight: FontWeight.w600,
                      ),
                    ),
                  for (final small in [true, false])
                    if ((small
                            ? _selections[item.id]!.smallQuantity
                            : _selections[item.id]!.largeQuantity) >
                        0)
                      _cartLine(item, small, updateSheet),
                ],
                const Divider(),
                Text(
                  'Итого: $_total / ${_scenario.budget} 🪙',
                  style: _type(
                    Theme.of(context).textTheme.titleLarge,
                    size: 20,
                    weight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartLine(ShoppingTripItem item, bool small, StateSetter updateSheet) {
    final selection = _selections[item.id]!;
    final package = small ? item.smallPackage : item.largePackage;
    final quantity = small ? selection.smallQuantity : selection.largeQuantity;
    final price = item.scenarioById(selection.priceScenarioId);
    final linePrice = quantity * (small ? price.smallPrice : price.largePrice);
    return Row(
      children: [
        Expanded(
          child: Text(
            '${package.label} ×$quantity — $linePrice 🪙',
            style: _type(Theme.of(context).textTheme.bodyLarge, size: 17),
          ),
        ),
        IconButton(
          tooltip: 'Убрать ${item.label} ${package.label}',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          iconSize: 27,
          onPressed: () {
            _quantity(item, small, -1);
            updateSheet(() {});
          },
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'Добавить ${item.label} ${package.label}',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          iconSize: 27,
          onPressed: quantity >= package.maxQuantity
              ? null
              : () {
                  _quantity(item, small, 1);
                  updateSheet(() {});
                },
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _checkout(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.medium),
    children: [
      Text(
        'Касса',
        style: _type(
          Theme.of(context).textTheme.headlineSmall,
          size: 23,
          weight: FontWeight.w700,
        ),
      ),
      for (final item in _scenario.items)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: _type(
                  Theme.of(context).textTheme.titleMedium,
                  size: 18,
                  weight: FontWeight.w600,
                ),
              ),
              Text(
                '${_amount(item, _itemAmount(item))} / нужно ${item.requirementLabel}',
                style: _type(Theme.of(context).textTheme.bodyLarge, size: 18),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.medium),
      Text(
        'Итого: $_total / ${_scenario.budget} 🪙',
        key: const Key('shopping-checkout-total'),
        style: _type(
          Theme.of(context).textTheme.titleLarge,
          size: 20,
          weight: FontWeight.w700,
        ),
      ),
      if (_incorrect case final incorrect?) ...[
        const SizedBox(height: AppSpacing.medium),
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in _scenario.items)
                if (incorrect.insufficientItemIds.contains(item.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.small),
                    child: Text(
                      '${switch (item.id) {
                        'water' => 'Воды',
                        'soap' => 'Мыла',
                        'cookies' => 'Печенья',
                        _ => item.label,
                      }} пока не хватает. Нужно не меньше ${item.requirementLabel}, в корзине ${_amount(item, incorrect.purchasedAmounts[item.id] ?? 0)}.',
                      style: _type(
                        Theme.of(context).textTheme.bodyLarge,
                        size: 17,
                      ),
                    ),
                  ),
              if (incorrect.overBudgetBy > 0)
                Text(
                  'Корзина дороже бюджета на ${incorrect.overBudgetBy} монет.',
                  style: _type(Theme.of(context).textTheme.bodyLarge, size: 17),
                ),
            ],
          ),
        ),
      ],
      if (_runtimeError)
        Text(
          'Не получилось проверить корзину. Попробуй ещё раз.',
          style: _type(Theme.of(context).textTheme.bodyLarge, size: 17),
        ),
      const SizedBox(height: AppSpacing.medium),
      FilledButton(
        key: const Key('shopping-check'),
        onPressed: _submitting ? null : _check,
        child: Text(
          _submitting ? 'Проверяем…' : 'Проверить корзину',
          style: _type(null, size: 16, weight: FontWeight.w700),
        ),
      ),
      OutlinedButton(
        onPressed: _submitting
            ? null
            : () => setState(() {
                _stage = _ShoppingStage.shelf;
                _incorrect = null;
              }),
        child: Text(
          '← Назад к полкам',
          style: _type(null, size: 16, weight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _success(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.medium),
    children: [
      Text(
        'Покупки готовы!',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text(
        'Всё из списка есть, и ты уложился в бюджет.',
        style: _type(Theme.of(context).textTheme.bodyLarge, size: 18),
      ),
      const SizedBox(height: AppSpacing.medium),
      Text(
        'Потрачено: $_total 🪙',
        style: _type(Theme.of(context).textTheme.bodyLarge, size: 18),
      ),
      Text(
        'Осталось: ${_scenario.budget - _total} 🪙',
        style: _type(Theme.of(context).textTheme.bodyLarge, size: 18),
      ),
      Text(
        '+${widget.task.reward} монет',
        style: _type(
          Theme.of(context).textTheme.titleLarge,
          size: 20,
          weight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppSpacing.medium),
      Text(
        _scenario.successExplanation,
        style: _type(Theme.of(context).textTheme.bodyLarge, size: 17),
      ),
      const SizedBox(height: AppSpacing.medium),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          'Готово',
          style: _type(null, size: 16, weight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _ShoppingCartDock extends StatelessWidget {
  const _ShoppingCartDock({
    required this.packageCount,
    required this.packageCountLabel,
    required this.total,
    required this.budget,
    required this.onTap,
  });

  final int packageCount;
  final String packageCountLabel;
  final int total;
  final int budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Корзина. $packageCountLabel. Потрачено $total из $budget монет.',
      child: ExcludeSemantics(
        child: Material(
          elevation: 4,
          shadowColor: theme.colorScheme.shadow.withValues(alpha: .18),
          color: theme.colorScheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('shopping-cart-bar'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: AppSpacing.small,
                ),
                child: Row(
                  children: [
                    _ShoppingCartIcon(
                      packageCount: packageCount,
                      disableAnimations: MediaQuery.of(context)
                          .disableAnimations,
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Корзина',
                            key: const Key('shopping-cart-title'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$packageCountLabel · $total / $budget 🪙',
                            key: const Key('shopping-cart-summary'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    const Icon(Icons.keyboard_arrow_up),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShoppingCartIcon extends StatefulWidget {
  const _ShoppingCartIcon({
    required this.packageCount,
    required this.disableAnimations,
  });

  final int packageCount;
  final bool disableAnimations;

  @override
  State<_ShoppingCartIcon> createState() => _ShoppingCartIconState();
}

class _ShoppingCartIconState extends State<_ShoppingCartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.06), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 1),
  ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant _ShoppingCartIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.packageCount != oldWidget.packageCount &&
        !widget.disableAnimations) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: ScaleTransition(
              scale: widget.disableAnimations
                  ? const AlwaysStoppedAnimation<double>(1)
                  : _scale,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_cart_rounded,
                  key: const Key('shopping-cart-icon'),
                  size: 30,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ),
          if (widget.packageCount > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                key: const Key('shopping-cart-count-badge'),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: colors.tertiary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${widget.packageCount}',
                  style: TextStyle(
                    color: colors.onTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductPainter extends CustomPainter {
  const _ProductPainter({
    required this.itemId,
    required this.large,
    required this.color,
  });

  final String itemId;
  final bool large;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = large ? 94.0 : 73.0;
    final height = large ? 132.0 : 105.0;
    final left = (size.width - width) / 2;
    final top = size.height - height - 6;
    final shadow = Paint()..color = Colors.black26;
    canvas.drawOval(
      Rect.fromLTWH(left + 2, size.height - 13, width + 8, 13),
      shadow,
    );
    final front = Paint()..color = color.withValues(alpha: .75);
    final side = Paint()..color = color.withValues(alpha: .45);
    if (itemId == 'water') {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 8, top + 25, width - 20, height - 25),
        const Radius.circular(10),
      );
      canvas.drawRRect(body, front);
      canvas.drawRect(Rect.fromLTWH(left + 24, top + 8, width - 52, 19), front);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 22, top, width - 48, 10),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
      canvas.drawRect(
        Rect.fromLTWH(left + width - 18, top + 30, 7, height - 35),
        side,
      );
      canvas.drawRect(
        Rect.fromLTWH(left + 14, top + height * .55, width - 33, 23),
        Paint()..color = Colors.white.withValues(alpha: .8),
      );
    } else if (itemId == 'soap') {
      final frontRect = Rect.fromLTWH(left, top + 7, width - 12, height - 7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(frontRect, const Radius.circular(5)),
        front,
      );
      final sidePath = Path()
        ..moveTo(left + width - 12, top + 7)
        ..lineTo(left + width, top)
        ..lineTo(left + width, top + height - 8)
        ..lineTo(left + width - 12, top + height)
        ..close();
      canvas.drawPath(sidePath, side);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 10, top + height * .38, width - 34, 30),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withValues(alpha: .85),
      );
      final bubbles = Paint()..color = Colors.white.withValues(alpha: .65);
      canvas.drawCircle(Offset(left + 24, top + height * .31), 7, bubbles);
      canvas.drawCircle(Offset(left + 37, top + height * .27), 4, bubbles);
    } else {
      final pouch = Path()
        ..moveTo(left + 8, top + 10)
        ..lineTo(left + width - 15, top + 10)
        ..lineTo(left + width - 8, top + height - 9)
        ..quadraticBezierTo(
          left + width / 2,
          top + height,
          left + 2,
          top + height - 9,
        )
        ..close();
      canvas.drawPath(pouch, front);
      final sidePath = Path()
        ..moveTo(left + width - 15, top + 10)
        ..lineTo(left + width - 5, top + 3)
        ..lineTo(left + width, top + height - 13)
        ..lineTo(left + width - 8, top + height - 9)
        ..close();
      canvas.drawPath(sidePath, side);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 4, top + 2, width - 12, 13),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
      final cookie = Paint()..color = const Color(0xFFE9BC76);
      final chip = Paint()..color = const Color(0xFF7B4E39);
      final center = Offset(left + (width - 12) / 2, top + height * .58);
      canvas.drawCircle(center, large ? 23 : 18, cookie);
      for (final offset in const [
        Offset(-8, -6),
        Offset(7, -7),
        Offset(-3, 6),
        Offset(10, 8),
      ]) {
        canvas.drawCircle(center + offset, 2.5, chip);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProductPainter oldDelegate) =>
      itemId != oldDelegate.itemId ||
      large != oldDelegate.large ||
      color != oldDelegate.color;
}
