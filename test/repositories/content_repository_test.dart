import 'package:finny/repositories/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and parses all foundation content assets', () async {
    final repository = AssetContentRepository();

    final tasks = await repository.loadTasks();
    final items = await repository.loadShopItems();
    final goals = await repository.loadGoals();
    final periods = await repository.loadPeriods();
    final glossary = await repository.loadGlossary();

    expect(tasks, isNotEmpty);
    expect(tasks.single.scenarioData, isNotEmpty);
    expect(items, hasLength(2));
    expect(goals, hasLength(3));
    expect(goals.every((goal) => goal.price > 0), isTrue);
    expect(periods, hasLength(5));
    expect(periods.map((period) => period.number), [1, 2, 3, 4, 5]);
    expect(periods.every((period) => period.baseIncome == 500), isTrue);
    expect(
      periods.every((period) => period.requiredCheckpoints.isNotEmpty),
      isTrue,
    );
    expect(glossary, isNotEmpty);
  });
}
