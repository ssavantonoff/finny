import 'dart:convert';

import 'package:finny/models/financial_task.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> source;
  setUp(() async {
    final text = await rootBundle.loadString('assets/content/tasks.json');
    final tasks = jsonDecode(text) as List<dynamic>;
    source = Map<String, dynamic>.from(
      tasks.singleWhere((task) => task['id'] == 'task_shopping_trip_04') as Map,
    );
  });

  Map<String, dynamic> copy() =>
      jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

  test(
    'canonical Day 4 parses with exact identity, prices and requirements',
    () {
      final task = FinancialTask.fromJson(copy());
      expect(task.id, 'task_shopping_trip_04');
      expect(task.type, 'shopping_trip');
      expect(task.reward, 50);
      expect(task.period, 4);
      expect(task.shoppingTripScenario.isCanonicalDay4, isTrue);
      expect(task.shoppingTripScenario.items.map((item) => item.id), [
        'water',
        'soap',
        'cookies',
      ]);
    },
  );

  test('invalid shopping content is rejected at parse boundary', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (task) => task['scenarioData']['budget'] = 0,
      (task) => task['scenarioData']['items'][1]['id'] = 'water',
      (task) => task['scenarioData']['items'][0]['requiredAmount'] = 0,
      (task) => task['scenarioData']['items'][0]['smallPackage']['amount'] = 0,
      (task) =>
          task['scenarioData']['items'][0]['largePackage']['maxQuantity'] = 0,
      (task) =>
          task['scenarioData']['items'][0]['priceScenarios'][0]['smallPrice'] =
              0,
      (task) => task['scenarioData']['items'][0]['priceScenarios'][1]['id'] =
          'small_better',
      (task) => task['scenarioData']['items'][0]['requiredAmount'] = 3000,
      (task) =>
          task['scenarioData']['items'][0]['smallPackage']['id'] = 'large',
      (task) => task['scenarioData']['prompt'] = '',
      (task) => task['scenarioData']['successExplanation'] = '',
    ];
    for (final mutate in mutations) {
      final task = copy();
      mutate(task);
      expect(() => FinancialTask.fromJson(task), throwsFormatException);
    }
  });

  test(
    'wrong canonical economics and task types are rejected appropriately',
    () {
      final changed = copy();
      changed['scenarioData']['items'][0]['priceScenarios'][0]['smallPrice'] =
          26;
      expect(
        FinancialTask.fromJson(changed).shoppingTripScenario.isCanonicalDay4,
        isFalse,
      );
      final unknown = copy()..['type'] = 'unknown';
      expect(() => FinancialTask.fromJson(unknown), throwsFormatException);
    },
  );

  test('campaign contains two Day 5 tasks and retains Days 1-4', () async {
    final tasks = await AssetContentRepository().loadTasks();
    expect(tasks.length, greaterThanOrEqualTo(6));
    expect(
      tasks.map((task) => task.topic).toSet().length,
      greaterThanOrEqualTo(3),
    );
    for (var day = 1; day <= 5; day++) {
      expect(
        tasks.where((task) => task.period == day && task.requiredForCheckpoint),
        hasLength(day == 5 ? 2 : 1),
      );
    }
    expect(
      tasks.map((task) => task.type).toSet(),
      containsAll([
        'categorization',
        'budget_priority',
        'plan_adaptation',
        'shopping_trip',
        'independent_budget',
        'plan_repair',
      ]),
    );
  });
}
