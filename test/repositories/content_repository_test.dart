import 'dart:convert';

import 'package:finny/models/financial_task.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _TasksBundle extends CachingAssetBundle {
  _TasksBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
}

Map<String, Object?> _validTaskJson() => {
  'id': 'task_need_or_want_01',
  'title': 'Нужно или хочется?',
  'topic': 'needs_and_wants',
  'description': 'Описание',
  'type': 'choice',
  'reward': 50,
  'period': 1,
  'scenarioData': <String, Object?>{
    'prompt': 'Финни проголодался. Что стоит купить в первую очередь?',
    'options': [
      <String, Object?>{'id': 'apple', 'label': 'Яблоко'},
      <String, Object?>{'id': 'ball', 'label': 'Мяч'},
      <String, Object?>{'id': 'decoration', 'label': 'Украшение'},
    ],
    'correctOptionId': 'apple',
    'explanation': 'Сначала нужное.',
  },
};

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
    expect(tasks.single.id, 'task_need_or_want_01');
    expect(tasks.single.period, 1);
    expect(tasks.single.reward, 50);
    expect(tasks.single.choiceScenario.options.map((option) => option.id), [
      'apple',
      'ball',
      'decoration',
    ]);
    expect(tasks.single.choiceScenario.correctOptionId, 'apple');
    expect(tasks.single.choiceScenario.explanation, isNotEmpty);
    expect(items, hasLength(2));
    final apple = items.singleWhere((item) => item.id == 'food_apple');
    final ball = items.singleWhere((item) => item.id == 'toy_ball');
    expect(
      (apple.petEffects.satiety, apple.usagePolicy),
      (20, ItemUsagePolicy.unlimited),
    );
    expect(
      (ball.petEffects.mood, ball.usagePolicy),
      (35, ItemUsagePolicy.oncePerPeriod),
    );
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

  test('duplicate task IDs are rejected across canonical asset', () async {
    final task = _validTaskJson();
    final repository = AssetContentRepository(
      bundle: _TasksBundle(jsonEncode([task, task])),
    );
    await expectLater(repository.loadTasks(), throwsFormatException);
  });

  test('choice task content rejects malformed canonical fields', () {
    final invalidCases = <String, void Function(Map<String, Object?>)>{
      'empty task ID': (task) => task['id'] = ' ',
      'empty title': (task) => task['title'] = '',
      'empty type': (task) => task['type'] = '',
      'unsupported type': (task) => task['type'] = 'unknown',
      'invalid period': (task) => task['period'] = 0,
      'invalid reward': (task) => task['reward'] = 0,
      'empty prompt': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['prompt'] = '',
      'one option': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['options'] = [
            {'id': 'apple', 'label': 'Яблоко'},
          ],
      'duplicate option IDs': (task) =>
          ((task['scenarioData'] as Map<String, Object?>)['options']
              as List)[1] = {
            'id': 'apple',
            'label': 'Мяч',
          },
      'empty option ID': (task) =>
          (((task['scenarioData'] as Map<String, Object?>)['options']
                      as List)[0]
                  as Map<String, Object?>)['id'] =
              '',
      'empty option label': (task) =>
          (((task['scenarioData'] as Map<String, Object?>)['options']
                      as List)[0]
                  as Map<String, Object?>)['label'] =
              ' ',
      'missing correct ID': (task) =>
          (task['scenarioData'] as Map<String, Object?>).remove(
            'correctOptionId',
          ),
      'empty correct ID': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['correctOptionId'] =
              '',
      'unknown correct ID': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['correctOptionId'] =
              'other',
      'empty explanation': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['explanation'] = ' ',
    };
    for (final entry in invalidCases.entries) {
      final task = _validTaskJson();
      entry.value(task);
      expect(
        () => FinancialTask.fromJson(task),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });
}
