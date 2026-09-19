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
