import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:finny/features/things/things_item_art.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _thingsActionStyle = FilledButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  disabledBackgroundColor: const Color(0xFFE2E0EE),
  disabledForegroundColor: const Color(0xFF7778A5),
  minimumSize: const Size(48, 48),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
);

enum _ThingsFilter {
  all('Все', Icons.apps_rounded),
  food('Еда', Icons.restaurant_rounded),
  care('Уход', Icons.shower_rounded),
  toys('Игрушки', Icons.sports_esports_rounded),
  room('Комната', Icons.weekend_rounded),
  accessories('Аксессуары', Icons.auto_awesome_rounded);

  const _ThingsFilter(this.label, this.icon);
  final String label;
  final IconData icon;

  bool includes(ShopItem item) => switch (this) {
    _ThingsFilter.all => true,
    _ThingsFilter.food => item.displaySection == ShopDisplaySection.food,
    _ThingsFilter.care => item.displaySection == ShopDisplaySection.care,
    _ThingsFilter.toys => item.displaySection == ShopDisplaySection.toys,
    _ThingsFilter.room => false, // No room section in canonical content yet.
    _ThingsFilter.accessories =>
      item.displaySection == ShopDisplaySection.accessories,
  };
}

class ThingsScreen extends ConsumerStatefulWidget {
  const ThingsScreen({super.key});
  @override
  ConsumerState<ThingsScreen> createState() => _ThingsScreenState();
}

class _ThingsScreenState extends ConsumerState<ThingsScreen> {
  _ThingsFilter _filter = _ThingsFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(thingsControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(thingsControllerProvider);
    final controller = ref.read(thingsControllerProvider.notifier);
    ref.listen<ThingsState>(thingsControllerProvider, (previous, next) {
      final wasSuccess = previous?.result?.kind == ItemUseResultKind.success;
      final isSuccess = next.result?.kind == ItemUseResultKind.success;
      if (!wasSuccess && isSuccess) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) GoRouter.maybeOf(context)?.go('/home');
        });
      }
    });
    ref.listen<int?>(activeProfileIdProvider, (_, _) => controller.load());

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0FF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Вещи',
                          style: TextStyle(
                            color: Color(0xFF1A2368),
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Твои вещи для Финни',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF7778A5)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Обновить инвентарь',
                    onPressed: state.mutating ? null : controller.load,
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.primaryDark,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView.separated(
                key: const Key('things-filters'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _ThingsFilter.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _ThingsFilter.values[index];
                  final selected = _filter == filter;
                  return Semantics(
                    selected: selected,
                    button: true,
                    child: InkWell(
                      key: Key('things-filter-${filter.name}'),
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => setState(() => _filter = filter),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.white70,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFDAD7F4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            else if (filter != _ThingsFilter.all)
                              Icon(filter.icon, size: 20),
                            if (selected || filter != _ThingsFilter.all)
                              const SizedBox(width: 6),
                            Text(
                              filter.label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF1A2368),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (state.load) {
                ThingsLoad.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                ThingsLoad.noProfile => const _MessageBody(
                  message: 'Профиль пока не выбран.',
                ),
                ThingsLoad.contentError => _ErrorBody(
                  message: 'Не получилось загрузить вещи. Попробуй ещё раз.',
                  onRetry: controller.load,
                ),
                ThingsLoad.runtimeError => _ErrorBody(
                  message: 'Не получилось открыть инвентарь. Попробуй ещё раз.',
                  onRetry: controller.load,
                ),
                ThingsLoad.ready => _ReadyBody(
                  state: state,
                  controller: controller,
                  filter: _filter,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.state,
    required this.controller,
    required this.filter,
  });
  final ThingsState state;
  final ThingsController controller;
  final _ThingsFilter filter;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            key: const Key('things-empty'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.backpack_outlined,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'У тебя пока нет вещей',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Загляни в магазин, чтобы купить что-нибудь для Финни.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('things-go-to-shop'),
                style: _thingsActionStyle,
                onPressed: () => context.go('/shop'),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Заглянуть в магазин'),
              ),
            ],
          ),
        ),
      );
    }

    final items = state.items.where(filter.includes).toList()
      ..sort((a, b) {
        const order = <ShopDisplaySection, int>{
          ShopDisplaySection.toys: 0,
          ShopDisplaySection.food: 1,
          ShopDisplaySection.care: 2,
          ShopDisplaySection.accessories: 3,
        };
        final sectionOrder = order[a.displaySection]!.compareTo(
          order[b.displaySection]!,
        );
        return sectionOrder != 0
            ? sectionOrder
            : state.items.indexOf(a).compareTo(state.items.indexOf(b));
      });
    return Column(
      children: [
        if (state.result case final result?)
          if (result.kind != ItemUseResultKind.success)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _Surface(
                child: Column(
                  children: [
                    Text(result.message ?? 'Произошла ошибка.'),
                    if (result.kind == ItemUseResultKind.ambiguous)
                      FilledButton.tonal(
                        key: const Key('things-retry'),
                        style: _thingsActionStyle,
                        onPressed: state.mutating ? null : controller.retry,
                        child: const Text('Попробовать снова'),
                      ),
                  ],
                ),
              ),
            ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: _Surface(
                    child: Text(
                      'В категории «${filter.label}» пока нет твоих вещей.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : GridView.builder(
                  key: const Key('things-grid'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 266,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _ItemCard(
                    item: items[index],
                    state: state,
                    controller: controller,
                  ),
                ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white),
    ),
    child: child,
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.state,
    required this.controller,
  });
  final ShopItem item;
  final ThingsState state;
  final ThingsController controller;

  @override
  Widget build(BuildContext context) {
    final status = state.actionStatus(item);
    final canUse = state.canUse(item);
    final section = item.displaySection;
    final isToy = section == ShopDisplaySection.toys;
    final isAccessory = section == ShopDisplaySection.accessories;
    final actionLabel = isToy
        ? 'Играть'
        : isAccessory
        ? state.equipped[item.equipSlot] == item.id && state.freePlay
              ? 'Снять'
              : 'Надеть'
        : 'Использовать';
    return Container(
      key: Key('things-item-${item.id}'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14736CBB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ThingsItemArt(item: item)),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2368),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            switch (section) {
              ShopDisplaySection.food => 'Еда',
              ShopDisplaySection.care => 'Уход',
              ShopDisplaySection.toys => 'Игрушка',
              ShopDisplaySection.accessories => 'Аксессуар',
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7778A5),
            ),
          ),
          if (status != null && !isAccessory) ...[
            const SizedBox(height: 2),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF7778A5)),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: isAccessory
                ? FilledButton.tonal(
                    key: Key('things-equip-${item.id}'),
                    style: _thingsActionStyle,
                    onPressed: state.freePlay && !state.mutating
                        ? () => controller.toggleAccessory(item)
                        : null,
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : item.id == 'toy_ball'
                ? FilledButton(
                    key: const Key('things-play-toy_ball'),
                    style: _thingsActionStyle,
                    onPressed: state.canPlayBall(item)
                        ? () => context.push('/toy-ball')
                        : null,
                    child: const Text('Играть'),
                  )
                : FilledButton(
                    key: Key('things-use-${item.id}'),
                    style: _thingsActionStyle,
                    onPressed: canUse && !state.mutating
                        ? () => controller.use(item)
                        : null,
                    child: state.mutating && state.pending?.item.id == item.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            actionLabel,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: _Surface(child: Text(message, textAlign: TextAlign.center)),
  );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: _Surface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: _thingsActionStyle,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    ),
  );
}
