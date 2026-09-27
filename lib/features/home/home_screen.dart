import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_modal_actions.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/home/campaign_event_controller.dart';
import 'package:finny/features/home/finny_sleep_dialog.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/story_event.dart';
import 'package:finny/models/virtual_day_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PetStatIndicator extends StatelessWidget {
  const PetStatIndicator({
    super.key,
    required this.label,
    required this.value,
    this.barKey,
    this.compact = false,
  });

  final String label;
  final int value;
  final Key? barKey;
  final bool compact;

  static Color accentFor(String label) => switch (label) {
    'Сытость' => AppColors.satiety,
    'Уход' => AppColors.care,
    _ => AppColors.mood,
  };

  static IconData iconFor(String label) => switch (label) {
    'Сытость' => Icons.restaurant_rounded,
    'Уход' => Icons.auto_awesome_rounded,
    _ => Icons.favorite_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = accentFor(label);
    final clamped = value.clamp(0, 100);
    return Semantics(
      label: '$label, $clamped из 100',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: compact ? 20 : 24,
                  height: compact ? 20 : 24,
                  child: Icon(
                    iconFor(label),
                    size: compact ? 14 : 16,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 2 : AppSpacing.tiny),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                key: barKey,
                value: clamped / 100.0,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFloatingHeader extends StatelessWidget {
  const _HomeFloatingHeader({
    required this.title,
    required this.balance,
    required this.freePlay,
    this.phase,
    this.compact = false,
  });

  final String title;
  final int balance;
  final bool freePlay;
  final VirtualDayPhase? phase;
  final bool compact;

  String get _phaseLabel => switch (phase) {
    VirtualDayPhase.morning => 'Утро',
    VirtualDayPhase.daytime => 'День',
    VirtualDayPhase.evening => 'Вечер',
    null => '',
  };

  IconData get _phaseIcon => switch (phase) {
    VirtualDayPhase.morning => Icons.wb_twilight_rounded,
    VirtualDayPhase.daytime => Icons.wb_sunny_rounded,
    VirtualDayPhase.evening => Icons.nights_stay_rounded,
    null => Icons.wb_sunny_rounded,
  };

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('home-floating-header'),
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const Key('home-day-chip'),
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.55),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 4 : 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!(compact && freePlay)) ...[
                      Icon(
                        freePlay
                            ? Icons.sports_esports_rounded
                            : Icons.calendar_month_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (freePlay
                                    ? Theme.of(context).textTheme.titleSmall
                                    : Theme.of(context).textTheme.bodyLarge)
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact && freePlay ? 12 : null,
                                ),
                      ),
                    ),
                    if (phase != null) ...[
                      SizedBox(width: compact ? 4 : 6),
                      Tooltip(
                        key: Key('home-phase-${phase!.name}'),
                        message: _phaseLabel,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.8,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: compact ? 20 : 22,
                            height: compact ? 20 : 22,
                            child: Icon(
                              _phaseIcon,
                              size: compact ? 14 : 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.small),
      SizedBox(
        height: 48,
        child: HomeWallet(
          key: const Key('home-wallet'),
          balance: balance,
          compact: compact,
        ),
      ),
      const SizedBox(width: AppSpacing.small),
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        ),
        child: IconButton(
          key: const Key('home-settings'),
          tooltip: 'Настройки',
          onPressed: () => context.push('/settings'),
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          icon: const Icon(Icons.settings_rounded, color: AppColors.primary),
        ),
      ),
    ],
  );
}

ButtonStyle _petActionStyle(BuildContext context, {bool compact = false}) =>
    FilledButton.styleFrom(
      minimumSize: Size(144, compact ? 36 : 40),
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
      backgroundColor: AppColors.surface.withValues(alpha: 0.88),
      foregroundColor: AppColors.primaryDark,
      disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.9),
      disabledForegroundColor: AppColors.textSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    );

class _HomeStatsBar extends StatelessWidget {
  const _HomeStatsBar({
    required this.satiety,
    required this.care,
    required this.mood,
    this.campaignKeys = false,
    this.compact = false,
  });

  final int satiety;
  final int care;
  final int mood;
  final bool campaignKeys;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-stats'),
    color: AppColors.surface.withValues(alpha: 0.84),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: PetStatIndicator(
              key: campaignKeys ? const Key('home-stat-satiety') : null,
              barKey: campaignKeys ? const Key('home-stat-satiety-bar') : null,
              label: 'Сытость',
              value: satiety,
              compact: compact,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: PetStatIndicator(
              key: campaignKeys ? const Key('home-stat-care') : null,
              barKey: campaignKeys ? const Key('home-stat-care-bar') : null,
              label: 'Уход',
              value: care,
              compact: compact,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: PetStatIndicator(
              key: campaignKeys ? const Key('home-stat-mood') : null,
              barKey: campaignKeys ? const Key('home-stat-mood-bar') : null,
              label: 'Настроение',
              value: mood,
              compact: compact,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeViewport extends StatelessWidget {
  const _HomeViewport({required this.builder});

  final Widget Function(
    BuildContext context,
    bool compact,
    bool stableCampaignLayout,
  )
  builder;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final navigationClearance =
            AppTheme.homeContentNavigationClearance +
            MediaQuery.viewPaddingOf(context).bottom;
        final usableHeight = constraints.maxHeight - navigationClearance;
        final compact =
            usableHeight < AppTheme.compactHomeContentHeight ||
            constraints.maxWidth < 400;
        final stableCampaignLayout =
            usableHeight >= AppTheme.stableHomeCompositionHeight;
        return Padding(
          key: const Key('home-content-viewport'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.medium,
            compact ? 2 : 4,
            AppSpacing.medium,
            navigationClearance,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: builder(context, compact, stableCampaignLayout),
            ),
          ),
        );
      },
    ),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _incomeSheetOpen = false;
  bool _eventDialogOpen = false;
  String? _eventLoadKey;

  bool get _isHomeVisible {
    if (!mounted) return false;
    try {
      return GoRouter.of(context).routeInformationProvider.value.uri.path ==
          '/home';
    } catch (_) {
      return ModalRoute.of(context)?.isCurrent ?? true;
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(homeControllerProvider.notifier).load);
  }

  Future<void> _startDay() async {
    final period = await ref.read(homeControllerProvider.notifier).startDay();
    if (!mounted || period == null || _incomeSheetOpen) return;
    _incomeSheetOpen = true;
    final current = ref.read(homeControllerProvider);
    if (current is! HomeReady) {
      _incomeSheetOpen = false;
      return;
    }
    await showGeneralDialog<void>(
      context: context,
      pageBuilder: (context, _, _) =>
          NewDayStartedScreen(period: period, pet: current.pet),
    );
    _incomeSheetOpen = false;
  }

  Future<void> _finishDay() async {
    final controller = ref.read(homeControllerProvider.notifier);
    final decision = await controller.evaluateBedtime();
    if (!mounted || decision == null) return;
    var allowFallback = false;
    switch (decision.type) {
      case BedtimeDecisionType.tooEarly:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ещё рано спать'),
            content: const Text(
              'У Финни ещё есть время для дел и заботы. Вернись к нему позже.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Хорошо'),
              ),
            ],
          ),
        );
        return;
      case BedtimeDecisionType.blockedByCheckpoints:
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Перед сном осталось важное дело'),
            content: Text(
              decision.unresolvedCheckpoints
                  .map(_checkpointBlockerText)
                  .join('\n\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Вернуться'),
              ),
              if (decision.unresolvedCheckpoints.contains('financial_task'))
                FilledButton(
                  key: const Key('home-blocker-go-task'),
                  onPressed: () => Navigator.pop(context, 'tasks'),
                  child: const Text('К заданию'),
                ),
              if (decision.unresolvedCheckpoints.contains('savings_decision'))
                FilledButton(
                  key: const Key('home-blocker-go-savings'),
                  onPressed: () => Navigator.pop(context, 'savings'),
                  child: const Text('К накоплениям'),
                ),
            ],
          ),
        );
        if (!mounted) return;
        if (action == 'tasks') context.go('/tasks');
        if (action == 'savings') context.go('/savings');
        return;
      case BedtimeDecisionType.ready:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => const FinnySleepDialog(),
        );
        if (confirmed != true) return;
        break;
      case BedtimeDecisionType.carePossible:
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Финни ещё не готов спать.'),
            content: Text(
              'Подними ${_statLabels(decision.statsNeedingCare)} '
              'в зелёную зону.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Вернуться'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'things'),
                child: const Text('Открыть Вещи'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'shop'),
                child: const Text('Открыть Магазин'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (action == 'things') context.go('/things');
        if (action == 'shop') context.go('/shop');
        return;
      case BedtimeDecisionType.fallbackAllowed:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Сегодня Финни нужна помощь'),
            content: const Text(
              'Сегодня уже не хватает доступных вещей и монет, чтобы '
              'привести все показатели Финни в зелёную зону.\n\n'
              'Можно завершить день сейчас. Завтра Финни начнёт день '
              'с более низким состоянием.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Вернуться'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Завершить день'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        allowFallback = true;
        break;
    }
    if (!mounted) return;
    final completed = await ref
        .read(homeControllerProvider.notifier)
        .sleep(allowFallback: allowFallback);
    if (completed && mounted) context.go('/period-summary');
  }

  Future<void> _showCampaignEvent(int walletBalance) async {
    if (_eventDialogOpen || !_isHomeVisible) return;
    final event = ref.read(campaignEventControllerProvider);
    if (event is! CampaignEventReady || event.storyEvent == null) {
      return;
    }
    _eventDialogOpen = true;
    final isNewEvent = event.storyEvent?.status == StoryEventStatus.armed;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration:
          !isNewEvent || MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => CampaignEventDialog(
        initialState: event,
        walletBalance: walletBalance,
      ),
      transitionBuilder: (_, animation, _, child) {
        final entrance = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: entrance,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(entrance),
            child: child,
          ),
        );
      },
    );
    _eventDialogOpen = false;
    if (mounted) {
      await ref.read(homeControllerProvider.notifier).load();
    }
  }

  Future<void> _openBowlPurchase() async {
    if (_eventDialogOpen) return;
    final prepared = await ref
        .read(homeControllerProvider.notifier)
        .prepareBowlPurchase();
    if (!mounted || !prepared) return;
    final home = ref.read(homeControllerProvider);
    if (home is HomeReady) {
      await _showCampaignEvent(home.gameState.walletBalance);
    }
  }

  String _statLabels(Set<PetStat> stats) => [
    if (stats.contains(PetStat.satiety)) 'Сытость',
    if (stats.contains(PetStat.care)) 'Уход',
    if (stats.contains(PetStat.mood)) 'Настроение',
  ].join(', ');

  String _checkpointBlockerText(String checkpoint) => switch (checkpoint) {
    'financial_task' => 'Осталось выполнить сегодняшнее финансовое задание.',
    'savings_decision' =>
      'Осталось решить, будешь ли ты сегодня откладывать монеты.',
    'changed_circumstance' => 'Проведи ещё немного времени с Финни.',
    _ => 'Осталось завершить одно важное дело этого дня.',
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    ref.listen<CampaignEventState>(campaignEventControllerProvider, (_, next) {
      if (next is CampaignEventReady && !_eventDialogOpen && _isHomeVisible) {
        final home = ref.read(homeControllerProvider);
        if (home is HomeReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isHomeVisible) {
              _showCampaignEvent(home.gameState.walletBalance);
            }
          });
        }
      }
    });

    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      controller.load();
    });

    if (state is HomeNeedsBootstrap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/startup');
      });
    }
    if (state is HomeReady && state.period?.id != null) {
      final key =
          '${state.profile.id}:${state.period!.id}:'
          '${state.period!.resolvedCheckpoints.join(',')}: '
          '${state.bowlEvent?.status.name}:${state.bowlEvent?.qualifyingInteractionCount}';
      if (_eventLoadKey != key) {
        _eventLoadKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(campaignEventControllerProvider.notifier).load();
          }
        });
      }
    }

    final page = switch (state) {
      HomeLoading() || HomeNeedsBootstrap() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      HomeFailure() => _HomeError(onRetry: controller.load),
      HomeReady(freePlay: true) => _FreePlayHome(
        state: state,
        controller: controller,
      ),
      HomeReady() => _HomeContent(
        state: state,
        controller: controller,
        onStartDay: _startDay,
        onFinishDay: _finishDay,
        onOpenBowl: _openBowlPurchase,
      ),
    };
    return Theme(data: AppTheme.home(Theme.of(context)), child: page);
  }
}

class _FreePlayHome extends ConsumerWidget {
  const _FreePlayHome({required this.state, required this.controller});
  final HomeReady state;
  final HomeController controller;

  Future<(int, int, int, int)> _collection(WidgetRef ref) async {
    final id = state.profile.id!;
    final content = ref.read(contentRepositoryProvider);
    final games = ref.read(gameRepositoryProvider);
    final goals = await content.loadGoals();
    final completed = await games.getCompletedGoals(id);
    final persistent = (await content.loadShopItems())
        .where((item) => item.persistent)
        .toList();
    var owned = 0;
    for (final item in persistent) {
      if (await games.getInventoryQuantity(id, item.id) > 0) owned++;
    }
    final canonicalIds = goals.map((goal) => goal.id).toSet();
    return (
      completed.where((goal) => canonicalIds.contains(goal.goalId)).length,
      goals.length,
      owned,
      persistent.length,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: Colors.transparent,
    body: HomeSceneBackdrop(
      child: _HomeViewport(
        builder: (context, compact, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeFloatingHeader(
              title: 'Свободный режим',
              balance: state.gameState.walletBalance,
              freePlay: true,
              compact: compact,
            ),
            SizedBox(height: compact ? 4 : AppSpacing.small),
            _HomeStatsBar(
              satiety: state.pet.satiety,
              care: state.pet.care,
              mood: state.pet.mood,
              compact: compact,
            ),
            SizedBox(height: compact ? 2 : AppSpacing.tiny),
            const Spacer(),
            FinnyRoomScene(
              key: const Key('free-play-daylight'),
              pet: state.pet,
              showBackground: false,
            ),
            Center(
              child: FinnyNameBadge(
                key: const Key('home-pet-name'),
                name: state.pet.name,
                compact: compact,
              ),
            ),
            SizedBox(height: compact ? 2 : AppSpacing.tiny),
            Center(
              child: FilledButton.icon(
                key: const Key('home-free-pet'),
                style: _petActionStyle(context, compact: compact),
                onPressed: state.interacting
                    ? null
                    : () => controller.performFreeInteraction(
                        FreePetInteraction.pet,
                      ),
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Погладить'),
              ),
            ),
            SizedBox(height: compact ? 2 : AppSpacing.tiny),
            FreePlayCatchCard(onPlay: () => context.push('/finny-catch')),
            SizedBox(height: compact ? 2 : AppSpacing.tiny),
            if (state.activeGoal case final goal?)
              HomeGoalCard(
                name: goal.name,
                saved: state.gameState.savedAmount,
                price: goal.price,
                compact: compact,
              )
            else
              FutureBuilder(
                future: _collection(ref),
                builder: (context, snapshot) {
                  final allGoalsReached =
                      snapshot.hasData &&
                      snapshot.data!.$1 == snapshot.data!.$2;
                  return HomeNoGoalCard(
                    saved: state.gameState.savedAmount,
                    title: allGoalsReached
                        ? 'Все цели достигнуты! ✓'
                        : 'Цель не выбрана',
                    onSelect: allGoalsReached
                        ? null
                        : () => context.go('/savings'),
                    compact: compact,
                  );
                },
              ),
            SizedBox(height: compact ? 2 : AppSpacing.tiny),
            FutureBuilder(
              future: Future.wait<Object?>([
                _collection(ref),
                ref.read(freePlayServiceProvider).equipped(state.profile.id!),
                ref.read(contentRepositoryProvider).loadShopItems(),
                ref
                    .read(gameRepositoryProvider)
                    .getCompletedGoals(state.profile.id!),
                ref.read(contentRepositoryProvider).loadGoals(),
              ]),
              builder: (context, snapshot) {
                String? collectionLabel;
                String? inventoryLabel;
                var collectionComplete = false;
                if (snapshot.hasData) {
                  final collection = snapshot.data![0] as (int, int, int, int);
                  final (goalCount, totalGoals, ownedCount, totalItems) =
                      collection;
                  final equipped =
                      snapshot.data![1] as Map<ShopEquipSlot, String>;
                  final items = snapshot.data![2] as List<ShopItem>;
                  final completed = snapshot.data![3] as List<CompletedGoal>;
                  final goals = snapshot.data![4] as List<SavingsGoal>;
                  final worn = items
                      .where((item) => equipped.values.contains(item.id))
                      .map((item) => item.name)
                      .toList();
                  final rewards = goals
                      .where(
                        (goal) =>
                            completed.any((done) => done.goalId == goal.id),
                      )
                      .map((goal) => goal.name)
                      .toList();
                  collectionLabel =
                      'Цели $goalCount/$totalGoals · Предметы $ownedCount/$totalItems';
                  inventoryLabel = [
                    if (worn.isNotEmpty) 'На Финни: ${worn.join(', ')}',
                    if (rewards.isNotEmpty) 'В доме: ${rewards.join(', ')}',
                  ].join(' · ');
                  collectionComplete =
                      goalCount == totalGoals && ownedCount == totalItems;
                }
                return Card(
                  key: const Key('free-play-collection'),
                  color: AppColors.surface.withValues(alpha: 0.84),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : AppSpacing.compact,
                      vertical: compact ? 4 : AppSpacing.small,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: compact ? 40 : 44,
                            height: compact ? 40 : 44,
                            child: Icon(
                              Icons.inventory_2_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.small),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Твоя коллекция',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: AppColors.textPrimary),
                              ),
                              Text(
                                collectionLabel ?? 'Загружаем коллекцию…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              if (!compact &&
                                  inventoryLabel?.isNotEmpty == true)
                                Text(
                                  inventoryLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              if (!compact && collectionComplete)
                                Text(
                                  'Всё для Финни собрано! ✓',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textPrimary),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.tiny),
                        TextButton(
                          key: const Key('free-play-recap'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => context.go('/finale?mode=recap'),
                          child: const Text('Итоги'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.state,
    required this.controller,
    required this.onStartDay,
    required this.onFinishDay,
    required this.onOpenBowl,
  });

  final HomeReady state;
  final HomeController controller;
  final VoidCallback onStartDay;
  final VoidCallback onFinishDay;
  final VoidCallback onOpenBowl;

  Widget _buildStatusContent(bool compact, GamePeriod? period) {
    if (period == null && state.completedDays > 0 && !state.allDaysCompleted) {
      return _BetweenDaysStatus(compact: compact);
    }
    if (period != null &&
        period.requiredCheckpoints.any(
          (id) => id == 'financial_task' || id == 'savings_decision',
        )) {
      return _RequiredActionsSummary(period: period, compact: compact);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final period = state.period;
    final title = period == null
        ? state.completedDays == 0
              ? 'Первый день'
              : 'Дом Финни'
        : 'День ${period.periodNumber}';

    final periodAllowsPetAction =
        period != null &&
        (period.status == GamePeriodStatus.active ||
            period.status == GamePeriodStatus.readyToFinish);

    final canPet =
        periodAllowsPetAction && state.petUsageCount == 0 && !state.interacting;

    final taskUnresolved =
        period?.requiredCheckpoints.contains('financial_task') == true &&
        period?.resolvedCheckpoints.contains('financial_task') != true;
    final savingsUnresolved =
        period?.requiredCheckpoints.contains('savings_decision') == true &&
        period?.resolvedCheckpoints.contains('savings_decision') != true;
    final activeActionPeriod =
        period?.status == GamePeriodStatus.active ||
        period?.status == GamePeriodStatus.readyToFinish;
    final phase = activeActionPeriod && period != null
        ? VirtualDayRules.phaseAt(period.dayProgress)
        : null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HomeSceneBackdrop(
        phase: phase,
        child: _HomeViewport(
          builder: (context, compact, stableCampaignLayout) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeFloatingHeader(
                title: title,
                balance: state.gameState.walletBalance,
                freePlay: false,
                phase: phase,
                compact: compact,
              ),
              SizedBox(height: compact ? 4 : AppSpacing.small),
              _HomeStatsBar(
                satiety: state.pet.satiety,
                care: state.pet.care,
                mood: state.pet.mood,
                campaignKeys: true,
                compact: compact,
              ),
              SizedBox(height: compact ? 2 : AppSpacing.tiny),
              const Spacer(),
              FinnyRoomScene(
                key: const Key('home-day-sky'),
                pet: state.pet,
                showBackground: false,
              ),
              Center(
                child: FinnyNameBadge(
                  key: const Key('home-pet-name'),
                  name: state.pet.name,
                  compact: compact,
                ),
              ),
              SizedBox(height: compact ? 2 : AppSpacing.tiny),
              Center(
                child: FilledButton.tonalIcon(
                  key: const Key('home-free-pet'),
                  style: _petActionStyle(context, compact: compact),
                  onPressed: canPet
                      ? () => controller.performFreeInteraction(
                          FreePetInteraction.pet,
                        )
                      : null,
                  icon: const Icon(Icons.favorite_outline),
                  label: Text(
                    state.petUsageCount > 0 ? 'Погладить ✓' : 'Погладить',
                  ),
                ),
              ),
              if (state.interactionNotice case final notice?) ...[
                const SizedBox(height: AppSpacing.tiny),
                _Notice(notice),
              ],
              if (state.startFailed) ...[
                const SizedBox(height: AppSpacing.tiny),
                const _Notice('Не получилось начать день. Попробуй ещё раз.'),
              ],
              if (state.finishFailed) ...[
                const SizedBox(height: AppSpacing.tiny),
                const _Notice(
                  'Не получилось завершить день. Попробуй ещё раз.',
                ),
              ],
              SizedBox(height: compact ? 2 : AppSpacing.tiny),
              if (state.allDaysCompleted)
                _Notice(
                  'Все 5 дней завершены • Финни — этап '
                  '${state.pet.developmentStage}',
                )
              else if (period == null)
                FilledButton(
                  key: const Key('home-start-day'),
                  onPressed: state.startingDay ? null : onStartDay,
                  child: Text(
                    state.startingDay
                        ? 'Начинаем…'
                        : state.completedDays == 0
                        ? 'Начать день'
                        : 'Начать следующий день',
                  ),
                )
              else if (period.status == GamePeriodStatus.planning)
                FilledButton(
                  key: const Key('home-continue-plan'),
                  onPressed: () => context.go('/budget'),
                  child: const Text('Продолжить план'),
                )
              else if ((period.status == GamePeriodStatus.active ||
                      period.status == GamePeriodStatus.readyToFinish) &&
                  VirtualDayRules.bedtimeReached(period.dayProgress))
                FilledButton(
                  key: const Key('home-finish-day'),
                  onPressed: state.finishingDay ? null : onFinishDay,
                  child: Text(
                    state.finishingDay ? 'Укладываем…' : 'Уложить Финни спать',
                  ),
                )
              else if (period.status == GamePeriodStatus.active ||
                  period.status == GamePeriodStatus.readyToFinish)
                taskUnresolved
                    ? FilledButton(
                        key: const Key('home-next-task'),
                        onPressed: () => context.go('/tasks'),
                        child: const Text('Выполнить задание'),
                      )
                    : savingsUnresolved
                    ? FilledButton(
                        key: const Key('home-next-savings'),
                        onPressed: () => context.go('/savings'),
                        child: const Text('Решить про накопления'),
                      )
                    : FilledButton(
                        key: const Key('home-view-plan'),
                        onPressed: () => context.go('/budget'),
                        child: const Text('Посмотреть план'),
                      ),
              if (state.activeGoal case final goal?) ...[
                const SizedBox(height: 5),
                HomeGoalCard(
                  name: goal.name,
                  saved: state.gameState.savedAmount,
                  price: goal.price,
                  compact: compact,
                ),
              ] else ...[
                const SizedBox(height: 5),
                HomeNoGoalCard(
                  saved: state.gameState.savedAmount,
                  onSelect: () => context.go('/savings'),
                  compact: compact,
                ),
              ],
              const SizedBox(height: 5),
              if (stableCampaignLayout)
                SizedBox(
                  height: compact ? 100 : 104,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildStatusContent(compact, period),
                  ),
                )
              else
                _buildStatusContent(compact, period),
              if (state.bowlEvent?.isOutstanding == true) ...[
                const SizedBox(height: 2),
                _BowlObligationCard(
                  event: state.bowlEvent!,
                  compact: compact,
                  onPressed:
                      period?.status == GamePeriodStatus.active ||
                          period?.status == GamePeriodStatus.readyToFinish
                      ? onOpenBowl
                      : null,
                  unavailableText: state.completedDays >= 5
                      ? 'Кампания завершена. Покупка осталась отложенной.'
                      : period == null
                      ? 'Купить можно после начала следующего дня.'
                      : 'Купить можно после подтверждения плана дня.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequiredActionsSummary extends StatelessWidget {
  const _RequiredActionsSummary({required this.period, this.compact = false});

  final GamePeriod period;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final checkpoints = period.requiredCheckpoints
        .where((id) => id == 'financial_task' || id == 'savings_decision')
        .toList(growable: false);

    if (checkpoints.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('home-required-actions'),
      color: AppColors.surface.withValues(alpha: 0.82),
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.tiny,
        vertical: compact ? 2 : AppSpacing.tiny,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : AppSpacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final cp in checkpoints)
              _RequiredActionRow(
                title: cp == 'financial_task' ? 'Задание дня' : 'Накопления',
                pendingText: cp == 'financial_task'
                    ? 'Нужно выполнить'
                    : 'Нужно решить',
                resolved: period.resolvedCheckpoints.contains(cp),
              ),
          ],
        ),
      ),
    );
  }
}

class _BetweenDaysStatus extends StatelessWidget {
  const _BetweenDaysStatus({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-between-days-status'),
    color: AppColors.surface.withValues(alpha: 0.82),
    child: SizedBox(
      height: compact ? 36 : 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        child: const Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: AppColors.primary),
            SizedBox(width: AppSpacing.small),
            Text('День завершён'),
          ],
        ),
      ),
    ),
  );
}

class _BowlObligationCard extends StatelessWidget {
  const _BowlObligationCard({
    required this.event,
    required this.onPressed,
    required this.unavailableText,
    this.compact = false,
  });

  final StoryEventSnapshot event;
  final VoidCallback? onPressed;
  final String unavailableText;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-bowl-obligation'),
    color: AppColors.surface.withValues(alpha: 0.84),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: compact ? 1 : AppSpacing.tiny,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pets_outlined,
            size: 20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Новая миска нужна · ${event.price} монет',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  onPressed == null
                      ? unavailableText
                      : 'Сейчас Финни пользуется временной миской',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('home-bowl-purchase'),
            onPressed: onPressed,
            child: const Text('Купить'),
          ),
        ],
      ),
    ),
  );
}

class _RequiredActionRow extends StatelessWidget {
  const _RequiredActionRow({
    required this.title,
    required this.pendingText,
    required this.resolved,
  });

  final String title;
  final String pendingText;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(
            resolved ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: resolved ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.tiny),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!resolved)
                  Text(
                    pendingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.tiny),
          if (resolved)
            Text(
              'Готово',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class NewDayStartedScreen extends StatelessWidget {
  const NewDayStartedScreen({
    required this.period,
    required this.pet,
    super.key,
  });

  final GamePeriod period;
  final Pet pet;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: FinnyFlowBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 750;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Chip(
                            label: Text(
                              'День ${period.periodNumber}',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            backgroundColor: AppColors.primaryLight,
                            side: BorderSide.none,
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 24),
                        const Text(
                          'Новый день начался!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Посмотрим, сколько у тебя сегодня.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 20),
                        Semantics(
                          image: true,
                          label: FinnyVisual.descriptionForPet(pet),
                          child: SizedBox(
                            height: compact ? 215 : 260,
                            child: Image.asset(
                              FinnyVisual.assetForPet(pet),
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        Container(
                          key: const Key('new-day-summary'),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A6C5CE7),
                                blurRadius: 25,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Сегодня доступно',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FinnyAmount('${period.startingBudget}', size: 56),
                              const SizedBox(height: 16),
                              _NewDayMoneyRow(
                                'С прошлого дня',
                                '${period.startWalletBalance}',
                              ),
                              const SizedBox(height: 8),
                              _NewDayMoneyRow(
                                'Новый доход',
                                '+${period.baseIncome}',
                                income: true,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 32),
                        FinnyFlowButton(
                          key: const Key('income-build-plan'),
                          label: 'Составить план',
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go('/budget');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _NewDayMoneyRow extends StatelessWidget {
  const _NewDayMoneyRow(this.label, this.amount, {this.income = false});
  final String label;
  final String amount;
  final bool income;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: income ? const Color(0xFFE9FAF4) : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(
          income ? Icons.stars_rounded : Icons.account_balance_wallet_rounded,
          color: income ? AppColors.success : AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        FinnyAmount(
          amount,
          size: 18,
          color: income ? AppColors.success : AppColors.textPrimary,
        ),
      ],
    ),
  );
}

class CampaignEventDialog extends ConsumerStatefulWidget {
  const CampaignEventDialog({
    super.key,
    required this.initialState,
    required this.walletBalance,
  });

  final CampaignEventReady initialState;
  final int walletBalance;

  @override
  ConsumerState<CampaignEventDialog> createState() =>
      _CampaignEventDialogState();
}

class _CampaignEventDialogState extends ConsumerState<CampaignEventDialog> {
  late CampaignEventReady _lastReady;

  @override
  void initState() {
    super.initState();
    _lastReady = widget.initialState;
  }

  bool _isMatchingReady(CampaignEventState next) =>
      next is CampaignEventReady &&
      next.kind == _lastReady.kind &&
      next.storyEvent != null;

  @override
  Widget build(BuildContext context) {
    ref.listen<CampaignEventState>(campaignEventControllerProvider, (_, next) {
      if (_isMatchingReady(next) && mounted) {
        setState(() => _lastReady = next as CampaignEventReady);
      }
    });
    final state = _lastReady;
    final controller = ref.read(campaignEventControllerProvider.notifier);
    final bowl = state.storyEvent;
    if (bowl == null) {
      return const PopScope(
        canPop: false,
        child: AlertDialog(content: Text('Не удалось загрузить событие.')),
      );
    }
    final bowlPrice = bowl.price;
    final bowlDecisionShown =
        state.message != null &&
        state.pending == null &&
        (bowl.status == StoryEventStatus.postponed ||
            bowl.status == StoryEventStatus.purchased);
    final bowlWallet = bowl.walletBalance;
    final bowlCanUseSavings = bowl.canUseSavings;
    final bowlDeficit = bowl.walletDeficit;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(
          bowlDecisionShown && bowl.status == StoryEventStatus.purchased
              ? Icons.check_circle_rounded
              : Icons.pets_rounded,
          size: 32,
          color: AppColors.primary,
        ),
        title: Text(
          bowlDecisionShown && bowl.status == StoryEventStatus.purchased
              ? 'Новая миска куплена'
              : bowl.status == StoryEventStatus.postponed
              ? 'Новая миска'
              : 'Ой! Миска Финни сломалась',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                bowlDecisionShown
                    ? bowl.status == StoryEventStatus.purchased
                          ? 'Теперь у Финни снова есть миска.'
                          : 'Пока Финни будет пользоваться временной миской.'
                    : bowl.status == StoryEventStatus.postponed
                    ? 'Новая миска всё ещё нужна. Пока Финни пользуется временной миской.'
                    : 'Финни нужна новая миска. Этой покупки не было в твоём плане.',
              ),
              if (bowlDecisionShown &&
                  bowl.status == StoryEventStatus.purchased) ...[
                const SizedBox(height: AppSpacing.small),
                Text('Баланс сейчас: $bowlWallet монет'),
                const SizedBox(height: 8),
                const Text(
                  'План остался прежним, но фактические расходы изменились. '
                  'Иногда важные траты появляются неожиданно.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (!bowlDecisionShown) ...[
                const SizedBox(height: AppSpacing.small),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Сейчас — $bowlWallet монет'),
                      Text('Новая миска — −$bowlPrice монет'),
                      if (bowlWallet >= bowlPrice)
                        Text('Останется — ${bowlWallet - bowlPrice} монет'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE4F2FF),
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 6,
                      ),
                      child: Text(
                        'Нужно',
                        style: TextStyle(
                          color: AppColors.need,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (bowlWallet < bowlPrice)
                  Text('Не хватает $bowlDeficit монет'),
                if (bowlCanUseSavings && bowlWallet < bowlPrice)
                  Text('В копилке: ${bowl.savedAmount} монет'),
              ],
              if (state.message != null &&
                  (!bowlDecisionShown ||
                      bowl.status != StoryEventStatus.purchased)) ...[
                const SizedBox(height: AppSpacing.small),
                Semantics(liveRegion: true, child: Text(state.message!)),
              ],
            ],
          ),
        ),
        actions: [
          if (bowlDecisionShown)
            FilledButton(
              key: const Key('campaign-bowl-understood'),
              style: FinnyModalActions.primary,
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          if (!bowlDecisionShown && bowlCanUseSavings && bowlWallet < bowlPrice)
            FilledButton(
              key: const Key('campaign-bowl-savings'),
              style: FinnyModalActions.primary,
              onPressed: state.mutating
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: const Text('Использовать накопления?'),
                          content: Text(
                            'Использовать $bowlDeficit монет из копилки? '
                            'Цель останется активной, но накоплений станет меньше.',
                          ),
                          actions: [
                            TextButton(
                              style: FinnyModalActions.secondary,
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              style: FinnyModalActions.primary,
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Использовать'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await controller.purchaseBowlFromSavings();
                      }
                    },
              child: Text('Взять $bowlDeficit из копилки и купить'),
            ),
          if (!bowlDecisionShown)
            TextButton(
              key: const Key('campaign-bowl-postpone'),
              style: FinnyModalActions.secondary,
              onPressed: state.mutating
                  ? null
                  : () async {
                      if (bowl.status == StoryEventStatus.postponed) {
                        Navigator.pop(context);
                      } else {
                        await controller.postponeBowl();
                      }
                    },
              child: const Text('Отложить покупку'),
            ),
          if (!bowlDecisionShown && bowlWallet >= bowlPrice)
            FilledButton(
              key: const Key('campaign-buy-bowl'),
              style: FinnyModalActions.primary,
              onPressed: state.mutating
                  ? null
                  : () async {
                      await controller.purchaseBowl();
                    },
              child: Text('Купить новую миску — $bowlPrice'),
            ),
          if (state.pending != null &&
              state.message != null &&
              !bowlDecisionShown)
            FilledButton.tonal(
              key: const Key('campaign-retry'),
              style: FinnyModalActions.primary,
              onPressed: state.mutating
                  ? null
                  : () async {
                      await controller.retry();
                    },
              child: const Text('Проверить ещё раз'),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface.withValues(alpha: 0.9),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Не получилось открыть дом Финни.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
