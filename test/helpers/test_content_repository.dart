import 'package:finny/models/content_entry.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';

class TestContentRepository implements ContentRepository {
  TestContentRepository(this.periods, {this.shopItems = const []});

  final List<PeriodDefinition> periods;
  final List<ShopItem> shopItems;

  @override
  Future<List<PeriodDefinition>> loadPeriods() async => periods;

  @override
  Future<List<GlossaryEntry>> loadGlossary() async => const [];

  @override
  Future<List<SavingsGoal>> loadGoals() async => const [];

  @override
  Future<List<ShopItem>> loadShopItems() async => shopItems;

  @override
  Future<List<FinancialTask>> loadTasks() async => const [];
}

List<PeriodDefinition> testPeriodDefinitions({int count = 2}) => [
  for (var number = 1; number <= count; number++)
    PeriodDefinition(
      id: 'period_$number',
      number: number,
      title: 'Период $number',
      baseIncome: 500,
      requiredCheckpoints: const [
        'financial_task',
        'mandatory_need',
        'savings_decision',
      ],
    ),
];
