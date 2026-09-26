import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_art.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';

class TaskBackdrop extends StatelessWidget {
  const TaskBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF7F7FC), Color(0xFFEDEBFF)],
      ),
    ),
  );
}

class TaskDayBadge extends StatelessWidget {
  const TaskDayBadge({required this.day, super.key});

  final int day;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('task-day-badge'),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'День $day',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class TaskScreenHeader extends StatelessWidget {
  const TaskScreenHeader({
    required this.day,
    required this.title,
    required this.description,
    required this.onClose,
    super.key,
  });

  final int day;
  final String title;
  final String description;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              tooltip: 'Закрыть',
              onPressed: onClose,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                foregroundColor: AppColors.primaryDark,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          const Spacer(),
          TaskDayBadge(day: day),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 29,
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        description,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    ],
  );
}

class TaskSurface extends StatelessWidget {
  const TaskSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120F0C68),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

class TaskPrimaryButton extends StatelessWidget {
  const TaskPrimaryButton({
    required this.label,
    required this.onPressed,
    this.keyName,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? keyName;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      key: keyName == null ? null : Key(keyName!),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD8D2FA),
        disabledForegroundColor: const Color(0xFF8F84CC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    ),
  );
}

class TaskCoinAmount extends StatelessWidget {
  const TaskCoinAmount({
    required this.text,
    this.coinSize = 23,
    this.fontSize = 17,
    super.key,
  });

  final String text;
  final double coinSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FinnyCatchArt(type: FinnyCatchObjectType.coin, size: coinSize),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class TaskItemArt extends StatelessWidget {
  const TaskItemArt({
    required this.taskItemId,
    required this.label,
    required this.shopItems,
    this.size = 48,
    super.key,
  });

  final String taskItemId;
  final String label;
  final Map<String, ShopItem> shopItems;
  final double size;

  static String? shopIdFor(String taskItemId) => switch (taskItemId) {
    'food' => 'food_feed',
    'shampoo' => 'care_shampoo',
    'bow' => 'accessory_bow',
    'comb' => 'care_comb',
    'ball' => 'toy_ball',
    'toy' => 'toy_ball',
    'food_feed' ||
    'care_shampoo' ||
    'care_comb' ||
    'toy_ball' ||
    'accessory_bow' => taskItemId,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final shopId = shopIdFor(taskItemId);
    final item = shopId == null ? null : shopItems[shopId];
    return SizedBox.square(
      key: Key('task-item-art-$taskItemId'),
      dimension: size,
      child: switch (taskItemId) {
        'scenario_waterer_05' => Image.asset(
          'assets/images/tasks/day5/waterer.png',
          fit: BoxFit.contain,
          semanticLabel: label,
        ),
        'savings' => FinnyCatchArt(type: FinnyCatchObjectType.coin, size: size),
        _ =>
          item == null
              ? Icon(
                  taskItemId == 'room_decoration'
                      ? Icons.weekend_rounded
                      : Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  size: size * 0.64,
                  semanticLabel: label,
                )
              : ShopItemArt(item: item),
      },
    );
  }
}

class TaskQuantityStepper extends StatelessWidget {
  const TaskQuantityStepper({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    this.decreaseKey,
    this.increaseKey,
    this.valueKey,
    super.key,
  });

  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final String decreaseTooltip;
  final String increaseTooltip;
  final Key? decreaseKey;
  final Key? increaseKey;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        key: decreaseKey,
        tooltip: decreaseTooltip,
        onPressed: onDecrease,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.primaryDark,
        ),
        icon: const Icon(Icons.remove_rounded),
      ),
      SizedBox(
        width: 36,
        child: Text(
          '$value',
          key: valueKey,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      IconButton(
        key: increaseKey,
        tooltip: increaseTooltip,
        onPressed: onIncrease,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.primaryDark,
        ),
        icon: const Icon(Icons.add_rounded),
      ),
    ],
  );
}

class TaskItemTile extends StatelessWidget {
  const TaskItemTile({
    required this.itemId,
    required this.label,
    required this.shopItems,
    required this.onTap,
    this.price,
    this.compact = false,
    this.selected = false,
    this.incorrect = false,
    this.onRemove,
    this.tileKey,
    super.key,
  });

  final String itemId;
  final String label;
  final Map<String, ShopItem> shopItems;
  final VoidCallback? onTap;
  final int? price;
  final bool compact;
  final bool selected;
  final bool incorrect;
  final VoidCallback? onRemove;
  final Key? tileKey;

  @override
  Widget build(BuildContext context) {
    final content = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskItemArt(
                taskItemId: itemId,
                label: label,
                shopItems: shopItems,
                size: 46,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (price != null)
                TaskCoinAmount(text: '$price', coinSize: 16, fontSize: 12),
            ],
          )
        : Row(
            children: [
              TaskItemArt(
                taskItemId: itemId,
                label: label,
                shopItems: shopItems,
                size: 46,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (price != null)
                      TaskCoinAmount(
                        text: '$price',
                        coinSize: 16,
                        fontSize: 12,
                      ),
                  ],
                ),
              ),
            ],
          );
    return Semantics(
      button: true,
      selected: selected,
      label: price == null ? label : '$label, $price монет',
      child: Material(
        color: selected
            ? AppColors.primaryLight
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 88 : 68),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: incorrect
                    ? AppColors.error
                    : selected
                    ? AppColors.primary
                    : const Color(0xFFDADBF3),
                width: incorrect || selected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: onRemove == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.only(top: 6),
                  child: Center(child: content),
                ),
                if (onRemove != null)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      key: Key('task-remove-$itemId'),
                      tooltip: 'Вернуть $label',
                      onPressed: onRemove,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.remove_circle_rounded, size: 21),
                      color: AppColors.primaryDark,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskDecisionZone extends StatelessWidget {
  const TaskDecisionZone({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.highlighted,
    required this.children,
    required this.onTap,
    this.zoneKey,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool highlighted;
  final List<Widget> children;
  final VoidCallback? onTap;
  final Key? zoneKey;

  @override
  Widget build(BuildContext context) => Material(
    color: Color.lerp(Colors.white, color, highlighted ? 0.22 : 0.11)!,
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      key: zoneKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 154),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: highlighted ? color : Colors.white,
            width: highlighted ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            if (children.isEmpty)
              Icon(
                Icons.add_circle_outline_rounded,
                size: 24,
                color: color.withValues(alpha: 0.55),
              )
            else
              for (final child in children) ...[
                child,
                const SizedBox(height: 6),
              ],
          ],
        ),
      ),
    ),
  );
}

class TaskUnresolvedSection extends StatelessWidget {
  const TaskUnresolvedSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => TaskSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final child in children)
                  SizedBox(width: width, child: child),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class TaskFeedbackPanel extends StatelessWidget {
  const TaskFeedbackPanel({
    required this.title,
    required this.children,
    this.titleKey,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) => TaskSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          key: titleKey,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class TaskSuccessPanel extends StatelessWidget {
  const TaskSuccessPanel({
    required this.reward,
    required this.explanation,
    required this.titleKey,
    required this.rewardKey,
    super.key,
  });

  final int reward;
  final String explanation;
  final Key titleKey;
  final Key rewardKey;

  @override
  Widget build(BuildContext context) => TaskSurface(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 72,
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            'Отлично!',
            key: titleKey,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: rewardKey,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(22),
          ),
          child: TaskCoinAmount(
            text: '+$reward монет',
            coinSize: 28,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          explanation,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class TaskBudgetPanel extends StatelessWidget {
  const TaskBudgetPanel({
    required this.budget,
    required this.remaining,
    required this.spent,
    this.error,
    super.key,
  });

  final int budget;
  final int remaining;
  final int spent;
  final String? error;

  @override
  Widget build(BuildContext context) => TaskSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _amount(
                'Бюджет',
                budget,
                const Key('budget-priority-budget'),
              ),
            ),
            Container(width: 1, height: 50, color: AppColors.border),
            const SizedBox(width: 12),
            Expanded(
              child: _amount(
                'Осталось',
                remaining,
                const Key('budget-priority-remaining'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            key: const Key('budget-priority-progress'),
            value: budget == 0 ? 0 : spent / budget,
            minHeight: 9,
            backgroundColor: AppColors.primaryLight,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$spent из $budget потрачено',
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              key: const Key('budget-priority-budget-error'),
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _amount(String label, int amount, Key key) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      TaskCoinAmount(
        key: key,
        text: '$amount монет',
        coinSize: 22,
        fontSize: 17,
      ),
    ],
  );
}
