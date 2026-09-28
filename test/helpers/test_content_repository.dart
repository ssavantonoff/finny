import 'package:finny/models/content_entry.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/content_repository.dart';

class TestContentRepository implements ContentRepository {
  TestContentRepository(
    this.periods, {
    this.shopItems = const [],
    this.goals = const [],
    this.tasks,
    this.stories = const [],
    this.promotions = const [],
  });

  final List<PeriodDefinition> periods;
  final List<ShopItem> shopItems;
  final List<SavingsGoal> goals;
  final List<FinancialTask>? tasks;
  final List<StoryPurchase> stories;
  final List<ShopPromotion> promotions;

  @override
  Future<List<StoryPurchase>> loadStoryPurchases() async => stories;

  @override
  Future<List<ShopPromotion>> loadPromotions() async => promotions;

  @override
  Future<List<PeriodDefinition>> loadPeriods() async => periods;

  @override
  Future<List<GlossaryEntry>> loadGlossary() async => const [];

  @override
  Future<List<SavingsGoal>> loadGoals() async => goals;

  @override
  Future<List<ShopItem>> loadShopItems() async => shopItems;

  @override
  Future<List<FinancialTask>> loadTasks() async =>
      tasks ?? [for (final period in periods) testFinancialTask(period.number)];
}

FinancialTask testFinancialTask(int periodNumber) => FinancialTask(
  id: 'task_period_$periodNumber',
  title: 'Финансовое решение',
  topic: 'budget',
  description: 'Тестовое задание',
  type: 'choice',
  reward: 50,
  period: periodNumber,
  requiredForCheckpoint: true,
  choiceScenario: const ChoiceTaskScenario(
    prompt: 'Финни проголодался. Что стоит купить в первую очередь?',
    options: [
      ChoiceTaskOption(id: 'apple', label: 'Яблоко'),
      ChoiceTaskOption(id: 'ball', label: 'Мяч'),
      ChoiceTaskOption(id: 'decoration', label: 'Украшение'),
    ],
    correctOptionId: 'apple',
    explanation: 'Когда Финни голоден, сначала стоит купить еду — яблоко.',
  ),
);

FinancialTask testCategorizationTask({
  String id = 'task_need_or_want_01',
  int period = 1,
}) => FinancialTask(
  id: id,
  title: 'Нужно или хочу?',
  topic: 'needs_and_wants',
  description: 'Разложи вещи Финни на нужное и желаемое.',
  type: 'categorization',
  reward: 50,
  period: period,
  requiredForCheckpoint: true,
  categorizationScenario: const CategorizationTaskScenario(
    prompt: 'Разложи вещи.',
    categories: [
      CategorizationTaskCategory(
        id: 'need',
        label: 'Нужно',
        description: 'Важная забота.',
      ),
      CategorizationTaskCategory(
        id: 'want',
        label: 'Хочу',
        description: 'Можно купить позже.',
      ),
    ],
    items: [
      CategorizationTaskItem(
        id: 'food',
        label: 'Корм',
        correctCategoryId: 'need',
        feedback: 'Корм нужен.',
      ),
      CategorizationTaskItem(
        id: 'ball',
        label: 'Мяч',
        correctCategoryId: 'want',
        feedback: 'Мяч может подождать.',
      ),
    ],
    successExplanation: 'Сначала важное.',
  ),
);

FinancialTask testBudgetPriorityTask({
  String id = 'task_priority_02',
  int period = 2,
}) => FinancialTask(
  id: id,
  title: 'Что важнее сейчас?',
  topic: 'priorities',
  description: 'Собери покупки и уложись в бюджет.',
  type: 'budget_priority',
  reward: 50,
  period: period,
  requiredForCheckpoint: true,
  budgetPriorityScenario: const BudgetPriorityTaskScenario(
    prompt: 'У Финни 150 монет на покупки.\nКорм закончился, шампунь почти закончился,\nа кепка очень понравилась Финни.',
    budget: 150,
    buyNowLabel: 'Купить сейчас',
    buyNowDescription: 'То, что берём в этот раз.',
    laterLabel: 'Оставить на потом',
    laterDescription: 'То, что можно отложить.',
    items: [
      BudgetPriorityTaskItem(
        id: 'food',
        label: 'Корм',
        price: 90,
        correctDecision: BudgetPriorityDecision.buyNow,
        feedback: 'Корм закончился — его важно купить сейчас.',
      ),
      BudgetPriorityTaskItem(
        id: 'shampoo',
        label: 'Шампунь',
        price: 60,
        correctDecision: BudgetPriorityDecision.buyNow,
        feedback:
            'После корма остаётся 60 монет — этого как раз хватает на шампунь.',
      ),
      BudgetPriorityTaskItem(
        id: 'bow',
        label: 'Кепка',
        price: 80,
        correctDecision: BudgetPriorityDecision.later,
        feedback: 'Кепка хочется купить, но сейчас важнее корм и шампунь.',
      ),
    ],
    incorrectExplanation:
        'Проверь, что сначала выбраны важные покупки и бюджет не превышен.',
    successExplanation: 'Ты сначала выбрал важные покупки и уложился в бюджет.\nЖелание можно оставить на потом.',
  ),
);

FinancialTask testPlanAdaptationTask({
  String id = 'task_changed_plan_03',
  int period = 3,
}) => FinancialTask(
  id: id,
  title: 'План изменился',
  topic: 'adapting_plan',
  description: 'Измени план после неожиданной потери денег.',
  type: 'plan_adaptation',
  reward: 50,
  period: period,
  requiredForCheckpoint: true,
  planAdaptationScenario: const PlanAdaptationTaskScenario(
    prompt: 'План был на 300 монет, но 80 потерялись.',
    originalPlan: 300,
    lostAmount: 80,
    availableBudget: 220,
    keepLabel: 'Оставить в плане',
    keepDescription: 'Важное и накопления.',
    laterLabel: 'Перенести на потом',
    laterDescription: 'Можно купить позже.',
    items: [
      PlanAdaptationTaskItem(
        id: 'food',
        label: 'Корм',
        price: 90,
        category: 'need',
        correctDecision: PlanAdaptationDecision.keep,
        feedback: 'Корм нужен сейчас.',
      ),
      PlanAdaptationTaskItem(
        id: 'shampoo',
        label: 'Шампунь',
        price: 60,
        category: 'need',
        correctDecision: PlanAdaptationDecision.keep,
        feedback: 'Шампунь нужен сейчас.',
      ),
      PlanAdaptationTaskItem(
        id: 'toy',
        label: 'Игрушка',
        price: 100,
        category: 'want',
        correctDecision: PlanAdaptationDecision.later,
        feedback: 'Игрушку можно отложить.',
      ),
      PlanAdaptationTaskItem(
        id: 'savings',
        label: 'Накопления',
        price: 50,
        category: 'savings',
        correctDecision: PlanAdaptationDecision.keep,
        feedback: 'Накопления можно сохранить.',
      ),
    ],
    incorrectExplanation: 'Проверь важные покупки и накопления.',
    successExplanation: 'План адаптирован.',
  ),
);

List<PeriodDefinition> testPeriodDefinitions({int count = 2}) => [
  for (var number = 1; number <= count; number++)
    PeriodDefinition(
      id: 'period_$number',
      number: number,
      title: 'Период $number',
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task', 'savings_decision'],
    ),
];
