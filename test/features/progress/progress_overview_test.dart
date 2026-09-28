import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/progress/progress_overview_controller.dart';
import 'package:finny/features/progress/progress_overview_screen.dart';
import 'package:finny/models/day_five_task.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/period_summary.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Games implements GameRepository {
  _Games(this.periods, this.completedIds);
  final List<GamePeriod> periods;
  final Set<String> completedIds;

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async => periods;

  @override
  Future<TaskProgress?> getTaskProgress(int profileId, String taskId) async =>
      completedIds.contains(taskId)
      ? TaskProgress(
          profileId: profileId,
          taskId: taskId,
          status: TaskProgressStatus.completed,
          rewardClaimed: true,
          scenarioState: const {},
          updatedAt: DateTime.utc(2026),
        )
      : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CompletionPort implements TaskCompletionPort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Savings extends SavingsService {
  _Savings(super.games, super.content, this.snapshot);
  final SavingsSnapshot snapshot;

  @override
  Future<SavingsSnapshot> loadSnapshot(int profileId) async => snapshot;
}

class _Tasks extends TaskService {
  _Tasks(super.games, super.completion, super.content, this.dayFive);
  final DayFiveTaskCompletion dayFive;

  @override
  Future<DayFiveTaskCompletion> loadDayFiveCompletion({
    required int profileId,
    required int periodId,
  }) async => dayFive;
}

class _Periods extends PeriodService {
  _Periods(super.games, super.content, this.summary);
  final PeriodSummary summary;
  int? requestedPeriodId;

  @override
  Future<PeriodSummary> getSummary({
    required int profileId,
    required int periodId,
  }) async {
    requestedPeriodId = periodId;
    return summary;
  }
}

const _goal = SavingsGoal(
  id: 'lamp',
  name: 'Ночник',
  price: 300,
  description: 'Ночник для Финни',
  rewardAssetId: 'reward_lamp',
);

const _summary = PeriodSummary(
  openingWalletBalance: 0,
  baseIncome: 300,
  startingBudget: 300,
  additionalIncome: 0,
  plannedNeed: 80,
  plannedWant: 50,
  plannedSavings: 70,
  plannedRemainder: 100,
  factNeed: 90,
  factWant: 40,
  factSavings: 70,
  factRemainder: 100,
);

GamePeriod _period(int day, GamePeriodStatus status) => GamePeriod(
  id: day,
  profileId: 1,
  definitionId: 'period_$day',
  periodNumber: day,
  startWalletBalance: 0,
  baseIncome: 300,
  extraIncome: 0,
  plannedNeed: 80,
  plannedWant: 50,
  plannedSavings: 70,
  plannedFree: 100,
  actualNeed: 90,
  actualWant: 40,
  actualSavings: 70,
  requiredCheckpoints: const [],
  resolvedCheckpoints: const [],
  growthPointsEarned: 0,
  status: status,
  createdAt: DateTime.utc(2026, 1, day),
);

SavingsSnapshot _savings({bool hasGoal = false}) => SavingsSnapshot(
  state: GameState(
    profileId: 1,
    walletBalance: 100,
    currentPeriod: 6,
    activeGoalId: hasGoal ? _goal.id : null,
    savedAmount: hasGoal ? 120 : 0,
    updatedAt: DateTime.utc(2026),
  ),
  goals: const [_goal],
  completedGoals: const [],
  period: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads canonical tasks, both Day 5 proofs, and only the latest completed summary', () async {
    final content = AssetContentRepository();
    final games = _Games(
      [
        _period(1, GamePeriodStatus.completed),
        _period(5, GamePeriodStatus.completed),
        _period(6, GamePeriodStatus.active),
      ],
      {'task_need_or_want_01'},
    );
    final periods = _Periods(games, content, _summary);
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
        savingsServiceProvider.overrideWithValue(
          _Savings(games, content, _savings(hasGoal: true)),
        ),
        taskServiceProvider.overrideWithValue(
          _Tasks(
            games,
            _CompletionPort(),
            content,
            const DayFiveTaskCompletion(
              legacyCompleted: false,
              completedTaskIds: {
                'task_independent_budget_05',
                'task_plan_repair_05',
              },
            ),
          ),
        ),
        periodServiceProvider.overrideWithValue(periods),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeProfileIdProvider.notifier).setActiveProfileId(1);

    final result = await container.read(progressOverviewProvider.future);
    expect(result.activeGoal?.name, 'Ночник');
    expect(result.savedAmount, 120);
    expect(result.completedTasks.map((task) => task.title), [
      'Нужно или хочу?',
      'Собери свой бюджет',
      'План изменился',
    ]);
    expect(result.completedTasks.map((task) => task.day), [1, 5, 5]);
    expect(result.lastCompletedPeriod?.periodNumber, 5);
    expect(result.lastSummary, same(_summary));
    expect(periods.requestedPeriodId, 5);
  });

  test('Day 5 partial and legacy completion stay separate', () async {
    Future<List<String>> titles(DayFiveTaskCompletion dayFive) async {
      final content = AssetContentRepository();
      final games = _Games([_period(5, GamePeriodStatus.active)], {});
      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
          savingsServiceProvider.overrideWithValue(
            _Savings(games, content, _savings()),
          ),
          taskServiceProvider.overrideWithValue(
            _Tasks(games, _CompletionPort(), content, dayFive),
          ),
        ],
      );
      container.read(activeProfileIdProvider.notifier).setActiveProfileId(1);
      try {
        final result = await container.read(progressOverviewProvider.future);
        return result.completedTasks.map((task) => task.title).toList();
      } finally {
        container.dispose();
      }
    }

    expect(
      await titles(
        const DayFiveTaskCompletion(
          legacyCompleted: false,
          completedTaskIds: {'task_independent_budget_05'},
        ),
      ),
      ['Собери свой бюджет'],
    );
    expect(
      await titles(
        const DayFiveTaskCompletion(
          legacyCompleted: true,
          completedTaskIds: {},
        ),
      ),
      ['Самостоятельный выбор'],
    );
  });

  test('empty profile has friendly empty data', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final result = await container.read(progressOverviewProvider.future);
    expect(result.completedTasks, isEmpty);
    expect(result.lastCompletedPeriod, isNull);
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('progress overview renders at $size without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressOverviewProvider.overrideWith(
              (ref) async => ProgressOverviewSnapshot(
                activeGoal: _goal,
                savedAmount: 120,
                completedTasks: const [
                  CompletedFinancialTask(day: 1, title: 'Нужно или хочу?'),
                  CompletedFinancialTask(day: 5, title: 'Собери свой бюджет'),
                  CompletedFinancialTask(day: 5, title: 'План изменился'),
                ],
                lastCompletedPeriod: _period(5, GamePeriodStatus.completed),
                lastSummary: _summary,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.home(AppTheme.light),
            home: const ProgressOverviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ночник'), findsOneWidget);
      expect(find.text('Накоплено: 120 из 300 монет'), findsOneWidget);
      expect(find.text('Осталось: 180 монет'), findsOneWidget);
      expect(find.text('День 5 — Собери свой бюджет'), findsOneWidget);
      expect(find.text('День 5 — План изменился'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('progress-overview-list')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.text('План'), findsOneWidget);
      expect(find.text('Факт'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('progress overview shows empty states', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressOverviewProvider.overrideWith(
            (ref) async => const ProgressOverviewSnapshot(
              activeGoal: null,
              savedAmount: 0,
              completedTasks: [],
              lastCompletedPeriod: null,
              lastSummary: null,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.home(AppTheme.light),
          home: const ProgressOverviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Цель пока не выбрана.'), findsOneWidget);
    expect(find.text('Ты ещё не выполнил финансовые задания.'), findsOneWidget);
    expect(
      find.text('Итоги появятся после первого завершённого дня.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
