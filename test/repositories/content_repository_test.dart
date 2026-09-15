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
    expect(goals.single.price, greaterThan(0));
    expect(periods.single.baseIncome, greaterThan(0));
    expect(glossary, isNotEmpty);
  });
}
