import 'dart:math';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/features/tasks/task_visual_components.dart';
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
  final _shelfScrollController = ScrollController();
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

  @override
  void dispose() {
    _shelfScrollController.dispose();
    super.dispose();
  }

  void _changeShelf(int index) {
    setState(() => _shelf = index);
    if (_shelfScrollController.hasClients) _shelfScrollController.jumpTo(0);
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

  IconData _iconFor(String itemId) => switch (itemId) {
    'water' => Icons.water_drop_rounded,
    'soap' => Icons.clean_hands_rounded,
    _ => Icons.cookie_rounded,
  };

  String _assetFor(String itemId, String packageId) =>
      'assets/images/tasks/day4/${itemId}_$packageId.png';

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestExit();
    },
    child: Scaffold(
      key: const Key('shopping-trip-screen'),
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: TaskBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: TaskScreenHeader(
                    day: widget.task.period,
                    title: switch (_stage) {
                      _ShoppingStage.checkout => 'Касса',
                      _ShoppingStage.success => 'Покупки готовы!',
                      _ => widget.task.title,
                    },
                    description: switch (_stage) {
                      _ShoppingStage.intro =>
                        'Выбери нужные покупки и уложись в бюджет.',
                      _ShoppingStage.shelf => 'Сравни размер упаковки и цену.',
                      _ShoppingStage.checkout =>
                        'Проверь корзину перед покупкой.',
                      _ShoppingStage.success =>
                        'Всё из списка есть, и ты уложился в бюджет.',
                    },
                    onClose: _submitting ? null : _requestExit,
                  ),
                ),
                Expanded(
                  child: switch (_stage) {
                    _ShoppingStage.intro => _intro(context),
                    _ShoppingStage.shelf => _shelfView(context),
                    _ShoppingStage.checkout => _checkout(context),
                    _ShoppingStage.success => _success(context),
                  },
                ),
                if (_stage == _ShoppingStage.shelf)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ShoppingCartDock(
                          packageCount: _packageCount,
                          packageCountLabel: _packageCountLabel,
                          total: _total,
                          budget: _scenario.budget,
                          onTap: _showCart,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_shelf > 0) ...[
                              IconButton(
                                tooltip: 'Предыдущая полка',
                                onPressed: () => _changeShelf(_shelf - 1),
                                icon: const Icon(Icons.arrow_back_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: TaskPrimaryButton(
                                keyName: 'shopping-next',
                                label: _shelf < _scenario.items.length - 1
                                    ? 'Следующая полка →'
                                    : 'К кассе',
                                onPressed:
                                    _itemAmount(_scenario.items[_shelf]) <
                                        _scenario.items[_shelf].requiredAmount
                                    ? null
                                    : () {
                                        if (_shelf <
                                            _scenario.items.length - 1) {
                                          _changeShelf(_shelf + 1);
                                        } else {
                                          setState(
                                            () => _stage =
                                                _ShoppingStage.checkout,
                                          );
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _intro(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      TaskSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Твоя задача',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _scenario.prompt,
              style: _type(
                const TextStyle(color: AppColors.textPrimary),
                size: 18,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final item in _scenario.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(_iconFor(item.id), color: AppColors.primary, size: 23),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${item.label} — не меньше ${item.requirementLabel}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Бюджет',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TaskCoinAmount(text: '${_scenario.budget} монет'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      TaskPrimaryButton(
        keyName: 'shopping-enter',
        label: 'В магазин',
        onPressed: () => setState(() => _stage = _ShoppingStage.shelf),
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
            controller: _shelfScrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              const SizedBox(height: 8),
              _ShoppingBudgetPanel(budget: _scenario.budget, total: _total),
              const SizedBox(height: 10),
              TaskSurface(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(_iconFor(item.id), color: AppColors.need, size: 28),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Нужно: не меньше ${item.requirementLabel}',
                            key: const Key('shopping-requirement'),
                            style: _type(
                              const TextStyle(color: AppColors.textPrimary),
                              size: 18,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Выбрано: ${_amount(item, _itemAmount(item))} из ${item.requirementLabel}${_itemAmount(item) >= item.requiredAmount ? ' ✓' : ''}',
                            key: const Key('shopping-current-requirement'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _product(item, smallLeft, prices)),
                  const SizedBox(width: 8),
                  Expanded(child: _product(item, !smallLeft, prices)),
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
      child: TaskSurface(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            SizedBox(
              height: 128,
              child: Center(
                child: Image.asset(
                  _assetFor(item.id, package.id),
                  key: Key('shopping-product-${item.id}-${package.id}'),
                  fit: BoxFit.contain,
                  semanticLabel: '${item.label} ${package.label}',
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
            TaskCoinAmount(
              key: Key('shopping-product-price-${item.id}-${package.id}'),
              text: '$price',
              coinSize: 20,
              fontSize: 20,
            ),
            TaskQuantityStepper(
              value: quantity,
              valueKey: Key('shopping-quantity-${item.id}-${package.id}'),
              decreaseKey: Key('shopping-minus-${item.id}-${package.id}'),
              increaseKey: Key('shopping-plus-${item.id}-${package.id}'),
              decreaseTooltip: 'Убрать ${package.label}',
              increaseTooltip: 'Добавить ${package.label}',
              onDecrease: quantity == 0
                  ? null
                  : () => _quantity(item, small, -1),
              onIncrease: quantity == package.maxQuantity
                  ? null
                  : () => _quantity(item, small, 1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.primaryLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) => Padding(
          padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 12),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  for (final small in [true, false])
                    if ((small
                            ? _selections[item.id]!.smallQuantity
                            : _selections[item.id]!.largeQuantity) >
                        0)
                      _cartLine(item, small, updateSheet),
                ],
                const SizedBox(height: 12),
                TaskSurface(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Итого',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TaskCoinAmount(
                        text: '$_total / ${_scenario.budget}',
                        fontSize: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
    return TaskSurface(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Image.asset(
              _assetFor(item.id, package.id),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${package.label} ×$quantity — $linePrice',
              style: _type(
                const TextStyle(color: AppColors.textPrimary),
                size: 15,
              ),
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
      ),
    );
  }

  Widget _checkout(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      for (final item in _scenario.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TaskSurface(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_iconFor(item.id), color: AppColors.need, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_amount(item, _itemAmount(item))} / нужно ${item.requirementLabel}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _itemAmount(item) >= item.requiredAmount
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _itemAmount(item) >= item.requiredAmount
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 4),
      TaskSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Итого',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TaskCoinAmount(
                  key: const Key('shopping-checkout-total'),
                  text: '$_total / ${_scenario.budget}',
                  fontSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _total > _scenario.budget
                  ? 'Не хватает ${_total - _scenario.budget} монет'
                  : 'Осталось: ${_scenario.budget - _total} монет',
              style: TextStyle(
                color: _total > _scenario.budget
                    ? AppColors.error
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      if (_incorrect case final incorrect?) ...[
        const SizedBox(height: 12),
        TaskFeedbackPanel(
          title: 'Проверь корзину',
          children: [
            for (final item in _scenario.items)
              if (incorrect.insufficientItemIds.contains(item.id))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${switch (item.id) {
                      'water' => 'Воды',
                      'soap' => 'Мыла',
                      'cookies' => 'Печенья',
                      _ => item.label,
                    }} пока не хватает. Нужно не меньше ${item.requirementLabel}, в корзине ${_amount(item, incorrect.purchasedAmounts[item.id] ?? 0)}.',
                  ),
                ),
            if (incorrect.overBudgetBy > 0)
              Text(
                'Корзина дороже бюджета на ${incorrect.overBudgetBy} монет.',
              ),
          ],
        ),
      ],
      if (_runtimeError) ...[
        const SizedBox(height: 12),
        const TaskFeedbackPanel(
          title: 'Не получилось проверить корзину.',
          children: [Text('Попробуй ещё раз.')],
        ),
      ],
      const SizedBox(height: 16),
      TaskPrimaryButton(
        keyName: 'shopping-check',
        label: _submitting ? 'Проверяем…' : 'Проверить корзину',
        onPressed: _submitting ? null : _check,
      ),
      TextButton(
        onPressed: _submitting
            ? null
            : () => setState(() {
                _stage = _ShoppingStage.shelf;
                _incorrect = null;
              }),
        child: const Text('← Назад к полкам'),
      ),
    ],
  );

  Widget _success(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      TaskSuccessPanel(
        reward: widget.task.reward,
        explanation: _scenario.successExplanation,
        titleKey: const Key('shopping-success-title'),
        rewardKey: const Key('shopping-success-reward'),
      ),
      const SizedBox(height: 12),
      TaskSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Потрачено: $_total монет'),
            Text('Осталось: ${_scenario.budget - _total} монет'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TaskPrimaryButton(
        label: 'Готово',
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}

class _ShoppingBudgetPanel extends StatelessWidget {
  const _ShoppingBudgetPanel({required this.budget, required this.total});

  final int budget;
  final int total;

  @override
  Widget build(BuildContext context) => TaskSurface(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Бюджет',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TaskCoinAmount(text: '$budget', fontSize: 20),
                ],
              ),
            ),
            Container(width: 1, height: 42, color: AppColors.border),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'В корзине',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TaskCoinAmount(text: '$total', fontSize: 20),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (total / budget).clamp(0, 1).toDouble(),
            minHeight: 9,
            backgroundColor: AppColors.primaryLight,
            color: total > budget ? AppColors.error : AppColors.primary,
          ),
        ),
        if (total > budget)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Не хватает ${total - budget} монет',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    ),
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
    return Semantics(
      button: true,
      label: 'Корзина. $packageCountLabel. Потрачено $total из $budget монет.',
      child: ExcludeSemantics(
        child: Material(
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: .15),
          color: Colors.white.withValues(alpha: .94),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white),
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            packageCountLabel,
                            key: const Key('shopping-cart-summary'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    TaskCoinAmount(
                      text: '$total / $budget',
                      coinSize: 19,
                      fontSize: 14,
                    ),
                    const Icon(
                      Icons.keyboard_arrow_up,
                      color: AppColors.primaryDark,
                    ),
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
