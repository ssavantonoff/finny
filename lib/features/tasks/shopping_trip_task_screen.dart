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
              child: Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: InkWell(
                  key: const Key('shopping-cart-bar'),
                  onTap: _showCart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_outlined),
                        const SizedBox(width: AppSpacing.small),
                        Expanded(child: Text('Корзина · $_packageCountLabel')),
                        Text('$_total / ${_scenario.budget} 🪙'),
                      ],
                    ),
                  ),
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
      Text(_scenario.prompt, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.medium),
      for (final item in _scenario.items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.small),
          child: Text('${item.label} — не меньше ${item.requirementLabel}'),
        ),
      const SizedBox(height: AppSpacing.large),
      FilledButton(
        key: const Key('shopping-enter'),
        onPressed: () => setState(() => _stage = _ShoppingStage.shelf),
        child: const Text('В магазин'),
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
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Нужно: не меньше ${item.requirementLabel}'),
              const SizedBox(height: AppSpacing.small),
              Text('Бюджет: ${_scenario.budget} 🪙'),
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
                        child: const Text('← Назад'),
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
          Text(package.label, style: Theme.of(context).textTheme.titleMedium),
          Text('$price 🪙'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: Key('shopping-minus-${item.id}-${package.id}'),
                tooltip: 'Убрать ${package.label}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: quantity == 0
                    ? null
                    : () => _quantity(item, small, -1),
                icon: const Icon(Icons.remove),
              ),
              Text(
                '$quantity',
                key: Key('shopping-quantity-${item.id}-${package.id}'),
              ),
              IconButton(
                key: Key('shopping-plus-${item.id}-${package.id}'),
                tooltip: 'Добавить ${package.label}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                Text('Корзина', style: Theme.of(context).textTheme.titleLarge),
                if (_packageCount == 0) const Text('Корзина пока пуста.'),
                for (final item in _scenario.items) ...[
                  if (_selections[item.id]!.smallQuantity > 0 ||
                      _selections[item.id]!.largeQuantity > 0)
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  for (final small in [true, false])
                    if ((small
                            ? _selections[item.id]!.smallQuantity
                            : _selections[item.id]!.largeQuantity) >
                        0)
                      _cartLine(item, small, updateSheet),
                ],
                const Divider(),
                Text('Итого: $_total / ${_scenario.budget} 🪙'),
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
        Expanded(child: Text('${package.label} ×$quantity — $linePrice 🪙')),
        IconButton(
          tooltip: 'Убрать ${item.label} ${package.label}',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () {
            _quantity(item, small, -1);
            updateSheet(() {});
          },
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'Добавить ${item.label} ${package.label}',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
      Text('Касса', style: Theme.of(context).textTheme.headlineSmall),
      for (final item in _scenario.items)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.medium),
          child: Text(
            '${item.label}\n${_amount(item, _itemAmount(item))} / нужно ${item.requirementLabel}',
          ),
        ),
      const SizedBox(height: AppSpacing.medium),
      Text('Итого: $_total / ${_scenario.budget} 🪙'),
      if (_incorrect case final incorrect?) ...[
        const SizedBox(height: AppSpacing.medium),
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in _scenario.items)
                if (incorrect.insufficientItemIds.contains(item.id))
                  Text(
                    '${switch (item.id) {
                      'water' => 'Воды',
                      'soap' => 'Мыла',
                      'cookies' => 'Печенья',
                      _ => item.label,
                    }} пока не хватает. Нужно не меньше ${item.requirementLabel}, в корзине ${_amount(item, incorrect.purchasedAmounts[item.id] ?? 0)}.',
                  ),
              if (incorrect.overBudgetBy > 0)
                Text(
                  'Корзина дороже бюджета на ${incorrect.overBudgetBy} монет.',
                ),
            ],
          ),
        ),
      ],
      if (_runtimeError)
        const Text('Не получилось проверить корзину. Попробуй ещё раз.'),
      const SizedBox(height: AppSpacing.medium),
      FilledButton(
        key: const Key('shopping-check'),
        onPressed: _submitting ? null : _check,
        child: Text(_submitting ? 'Проверяем…' : 'Проверить корзину'),
      ),
      OutlinedButton(
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
    padding: const EdgeInsets.all(AppSpacing.medium),
    children: [
      Text(
        'Покупки готовы!',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text('Всё из списка есть, и ты уложился в бюджет.'),
      const SizedBox(height: AppSpacing.medium),
      Text('Потрачено: $_total 🪙'),
      Text('Осталось: ${_scenario.budget - _total} 🪙'),
      Text('+${widget.task.reward} монет'),
      const SizedBox(height: AppSpacing.medium),
      Text(_scenario.successExplanation),
      const SizedBox(height: AppSpacing.medium),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Готово'),
      ),
    ],
  );
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
