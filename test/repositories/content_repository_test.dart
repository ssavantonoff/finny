import 'dart:convert';

import 'package:finny/models/financial_task.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
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
  'requiredForCheckpoint': true,
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

Map<String, Object?> _validCategorizationTaskJson() => {
  'id': 'task_need_or_want_01',
  'title': 'Нужно или хочу?',
  'topic': 'needs_and_wants',
  'description': 'Разложи вещи Финни на нужное и желаемое.',
  'type': 'categorization',
  'reward': 50,
  'period': 1,
  'requiredForCheckpoint': true,
  'scenarioData': <String, Object?>{
    'prompt': 'Разложи вещи.',
    'categories': [
      <String, Object?>{
        'id': 'need',
        'label': 'Нужно',
        'description': 'Важная забота.',
      },
      <String, Object?>{
        'id': 'want',
        'label': 'Хочу',
        'description': 'Можно купить позже.',
      },
    ],
    'items': [
      <String, Object?>{
        'id': 'food',
        'label': 'Корм',
        'correctCategoryId': 'need',
        'feedback': 'Корм нужен.',
      },
      <String, Object?>{
        'id': 'ball',
        'label': 'Мяч',
        'correctCategoryId': 'want',
        'feedback': 'Мяч может подождать.',
      },
    ],
    'successExplanation': 'Сначала важное.',
  },
};

Map<String, Object?> _validBudgetPriorityTaskJson() => {
  'id': 'task_priority_02',
  'title': 'Что купить сначала?',
  'topic': 'priorities',
  'description': 'Собери покупки и уложись в бюджет.',
  'type': 'budget_priority',
  'reward': 50,
  'period': 2,
  'requiredForCheckpoint': true,
  'scenarioData': <String, Object?>{
    'prompt': 'Раздели покупки.',
    'budget': 150,
    'buyNowLabel': 'Купить сейчас',
    'buyNowDescription': 'Самое важное в пределах бюджета.',
    'laterLabel': 'Оставить на потом',
    'laterDescription': 'То, что может подождать.',
    'items': [
      <String, Object?>{
        'id': 'food',
        'label': 'Корм',
        'price': 90,
        'correctDecision': 'buy_now',
        'feedback': 'Корм нужен каждый день.',
      },
      <String, Object?>{
        'id': 'shampoo',
        'label': 'Шампунь',
        'price': 60,
        'correctDecision': 'buy_now',
        'feedback': 'Шампунь нужен для ухода.',
      },
      <String, Object?>{
        'id': 'bow',
        'label': 'Наушники',
        'price': 80,
        'correctDecision': 'later',
        'feedback': 'Наушники могут подождать.',
      },
    ],
    'incorrectExplanation': 'Проверь важность и бюджет.',
    'successExplanation': 'Важные покупки укладываются в бюджет.',
  },
};

Map<String, Object?> _validShopJson() => {
  'id': 'food_apple',
  'name': 'Яблоко',
  'displaySection': 'food',
  'category': 'NEED',
  'price': 40,
  'persistent': false,
  'usagePolicy': 'unlimited',
  'effects': <String, Object?>{'satiety': 20, 'care': 0, 'mood': 0},
  'effectType': 'satiety',
  'effectValue': 20,
  'unlockType': 'available',
};

FinancialTask _copyTask(FinancialTask task, {bool? requiredForCheckpoint}) =>
    FinancialTask(
      id: task.id,
      title: task.title,
      topic: task.topic,
      description: task.description,
      type: task.type,
      reward: task.reward,
      period: task.period,
      requiredForCheckpoint:
          requiredForCheckpoint ?? task.requiredForCheckpoint,
      dayProgressCost: task.dayProgressCost,
      choiceScenario: task.type == 'choice' ? task.choiceScenario : null,
      categorizationScenario: task.type == 'categorization'
          ? task.categorizationScenario
          : null,
      budgetPriorityScenario: task.type == 'budget_priority'
          ? task.budgetPriorityScenario
          : null,
      independentBudgetScenario: task.type == 'independent_budget'
          ? task.independentBudgetScenario
          : null,
      planRepairScenario: task.type == 'plan_repair'
          ? task.planRepairScenario
          : null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and parses all foundation content assets', () async {
    final repository = AssetContentRepository();

    final tasks = await repository.loadTasks();
    final items = await repository.loadShopItems();
    final stories = await repository.loadStoryPurchases();
    final promotions = await repository.loadPromotions();
    final goals = await repository.loadGoals();
    final periods = await repository.loadPeriods();
    final glossary = await repository.loadGlossary();

    expect(tasks, hasLength(6));
    final dayOne = tasks.singleWhere(
      (task) => task.id == 'task_need_or_want_01',
    );
    expect(dayOne.period, 1);
    expect(dayOne.reward, 50);
    expect(dayOne.requiredForCheckpoint, isTrue);
    expect(dayOne.type, 'categorization');
    expect(dayOne.categorizationScenario.categories.map((item) => item.id), [
      'need',
      'want',
    ]);
    expect(dayOne.categorizationScenario.items, hasLength(6));
    expect(dayOne.categorizationScenario.successExplanation, isNotEmpty);
    final dayTwo = tasks.singleWhere((task) => task.id == 'task_priority_02');
    expect(dayTwo.period, 2);
    expect(dayTwo.reward, 50);
    expect(dayTwo.requiredForCheckpoint, isTrue);
    expect(dayTwo.type, 'budget_priority');
    expect(dayTwo.budgetPriorityScenario.budget, 150);
    expect(
      [
        for (final item in dayTwo.budgetPriorityScenario.items)
          (item.id, item.price, item.correctDecision.wireValue),
      ],
      [
        ('food', 90, 'buy_now'),
        ('shampoo', 60, 'buy_now'),
        ('bow', 80, 'later'),
      ],
    );
    expect(tasks.where((task) => task.requiredForCheckpoint), hasLength(6));
    expect(tasks.any((task) => task.id == 'task_final_choice_05'), isFalse);
    expect(tasks.any((task) => task.id == 'task_bonus_reserve_05'), isFalse);
    expect(
      tasks
          .singleWhere((task) => task.id == 'task_independent_budget_05')
          .dayProgressCost,
      15,
    );
    expect(
      tasks
          .singleWhere((task) => task.id == 'task_plan_repair_05')
          .dayProgressCost,
      15,
    );
    expect(
      tasks.map((task) => task.topic).toSet().length,
      greaterThanOrEqualTo(3),
    );
    expect(items, hasLength(12));
    expect(
      (
        stories.single.id,
        stories.single.period,
        stories.single.price,
        stories.single.category,
        stories.single.checkpoint,
      ),
      (
        'day3_bowl_replacement',
        3,
        120,
        ShopItemCategory.need,
        'changed_circumstance',
      ),
    );
    expect(
      (
        promotions.single.id,
        promotions.single.period,
        promotions.single.itemId,
        promotions.single.promoPrice,
        promotions.single.maxPromoQuantity,
      ),
      ('day4_treat_discount', 4, 'food_treat', 35, 1),
    );
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

  test('canonical catalog has the exact twelve approved items', () async {
    final items = await AssetContentRepository().loadShopItems();
    final expected =
        <
          String,
          (
            String,
            ShopDisplaySection,
            ShopItemCategory,
            int,
            bool,
            ItemUsagePolicy,
            int,
            int,
            int,
            ShopEquipSlot?,
          )
        >{
          'food_apple': (
            'Яблоко',
            ShopDisplaySection.food,
            ShopItemCategory.need,
            40,
            false,
            ItemUsagePolicy.unlimited,
            20,
            0,
            0,
            null,
          ),
          'food_feed': (
            'Корм',
            ShopDisplaySection.food,
            ShopItemCategory.need,
            90,
            false,
            ItemUsagePolicy.unlimited,
            50,
            0,
            0,
            null,
          ),
          'food_treat': (
            'Звёздное печенье',
            ShopDisplaySection.food,
            ShopItemCategory.want,
            60,
            false,
            ItemUsagePolicy.unlimited,
            10,
            0,
            10,
            null,
          ),
          'care_shampoo': (
            'Шампунь',
            ShopDisplaySection.care,
            ShopItemCategory.need,
            60,
            false,
            ItemUsagePolicy.unlimited,
            0,
            40,
            0,
            null,
          ),
          'care_comb': (
            'Полотенце',
            ShopDisplaySection.care,
            ShopItemCategory.need,
            70,
            true,
            ItemUsagePolicy.oncePerPeriod,
            0,
            25,
            0,
            null,
          ),
          'care_toothbrush': (
            'Зубная щётка',
            ShopDisplaySection.care,
            ShopItemCategory.need,
            80,
            true,
            ItemUsagePolicy.toothbrush,
            0,
            8,
            0,
            null,
          ),
          'toy_ball': (
            'Мяч',
            ShopDisplaySection.toys,
            ShopItemCategory.want,
            120,
            true,
            ItemUsagePolicy.oncePerPeriod,
            0,
            0,
            35,
            null,
          ),
          'toy_frisbee': (
            'Фрисби',
            ShopDisplaySection.toys,
            ShopItemCategory.want,
            140,
            true,
            ItemUsagePolicy.oncePerPeriod,
            0,
            0,
            40,
            null,
          ),
          'toy_plush': (
            'Машинка',
            ShopDisplaySection.toys,
            ShopItemCategory.want,
            160,
            true,
            ItemUsagePolicy.oncePerPeriod,
            0,
            0,
            30,
            null,
          ),
          'accessory_bow': (
            'Наушники',
            ShopDisplaySection.accessories,
            ShopItemCategory.want,
            80,
            true,
            ItemUsagePolicy.none,
            0,
            0,
            0,
            ShopEquipSlot.head,
          ),
          'accessory_collar': (
            'Очки',
            ShopDisplaySection.accessories,
            ShopItemCategory.want,
            150,
            true,
            ItemUsagePolicy.none,
            0,
            0,
            0,
            ShopEquipSlot.neck,
          ),
          'accessory_hat': (
            'Крылья',
            ShopDisplaySection.accessories,
            ShopItemCategory.want,
            180,
            true,
            ItemUsagePolicy.none,
            0,
            0,
            0,
            ShopEquipSlot.head,
          ),
        };
    expect(items, hasLength(expected.length));
    expect(items.map((item) => item.id).toSet(), expected.keys.toSet());
    for (final item in items) {
      expect(
        (
          item.name,
          item.displaySection,
          item.category,
          item.price,
          item.persistent,
          item.usagePolicy,
          item.petEffects.satiety,
          item.petEffects.care,
          item.petEffects.mood,
          item.equipSlot,
        ),
        expected[item.id],
        reason: item.id,
      );
    }
    expect(items.map((item) => item.displaySection), [
      for (final section in ShopDisplaySection.values) ...[
        section,
        section,
        section,
      ],
    ]);
  });

  test('shop content rejects malformed values and duplicate IDs', () {
    final invalidCases = <String, void Function(Map<String, Object?>)>{
      'empty ID': (json) => json['id'] = ' ',
      'empty name': (json) => json['name'] = ' ',
      'zero price': (json) => json['price'] = 0,
      'unsupported section': (json) => json['displaySection'] = 'other',
      'unsupported category': (json) => json['category'] = 'OTHER',
      'negative effect': (json) =>
          (json['effects'] as Map<String, Object?>)['satiety'] = -1,
      'unsupported effect': (json) =>
          (json['effects'] as Map<String, Object?>)['energy'] = 1,
      'consumable with restricted policy': (json) =>
          json['usagePolicy'] = 'oncePerPeriod',
      'unsupported unlock': (json) => json['unlockType'] = 'mystery',
      'invalid equip slot': (json) => json['equipSlot'] = 'feet',
    };
    for (final entry in invalidCases.entries) {
      final json = _validShopJson();
      entry.value(json);
      expect(
        () => validateShopContent([ShopItem.fromJson(json)]),
        throwsFormatException,
        reason: entry.key,
      );
    }
    final apple = ShopItem.fromJson(_validShopJson());
    expect(() => validateShopContent([apple, apple]), throwsFormatException);
    final invalidAccessory = _validShopJson()
      ..['displaySection'] = 'accessories'
      ..['persistent'] = true
      ..['usagePolicy'] = 'none'
      ..['equipSlot'] = 'head';
    expect(
      () => validateShopContent([ShopItem.fromJson(invalidAccessory)]),
      throwsFormatException,
    );
  });

  test(
    'special content rejects duplicate IDs and invalid promotion pricing',
    () {
      const story = StoryPurchase(
        id: 'day3_bowl_replacement',
        name: 'Новая миска',
        period: 3,
        price: 120,
        category: ShopItemCategory.need,
        checkpoint: 'changed_circumstance',
      );
      const promo = ShopPromotion(
        id: 'day4_treat_discount',
        period: 4,
        itemId: 'food_apple',
        promoPrice: 35,
        maxPromoQuantity: 1,
      );
      final apple = ShopItem.fromJson(_validShopJson());
      validateSpecialContent(const [story], const [promo], [apple]);
      expect(
        () => validateSpecialContent(const [story, story], const [promo], [
          apple,
        ]),
        throwsFormatException,
      );
      expect(
        () => validateSpecialContent(
          const [story],
          [
            const ShopPromotion(
              id: 'day3_bowl_replacement',
              period: 4,
              itemId: 'food_apple',
              promoPrice: 35,
              maxPromoQuantity: 1,
            ),
          ],
          [apple],
        ),
        throwsFormatException,
      );
      expect(
        () => validateSpecialContent(
          const [story],
          [
            const ShopPromotion(
              id: 'day4_treat_discount',
              period: 4,
              itemId: 'food_apple',
              promoPrice: 40,
              maxPromoQuantity: 1,
            ),
          ],
          [apple],
        ),
        throwsFormatException,
      );
      expect(
        () => validateSpecialContent(
          const [story],
          [
            const ShopPromotion(
              id: 'day4_treat_discount',
              period: 4,
              itemId: 'missing',
              promoPrice: 35,
              maxPromoQuantity: 1,
            ),
          ],
          [apple],
        ),
        throwsFormatException,
      );
    },
  );

  test('duplicate task IDs are rejected across canonical asset', () async {
    final task = _validTaskJson();
    final repository = AssetContentRepository(
      bundle: _TasksBundle(jsonEncode([task, task])),
    );
    await expectLater(repository.loadTasks(), throwsFormatException);
  });

  test('campaign requires one task on Days 1-4 and two on Day 5', () async {
    final tasks = await AssetContentRepository().loadTasks();
    expect(() => validateCampaignTaskContent(tasks), returnsNormally);

    final withoutDayThree = tasks
        .where((task) => task.period != 3)
        .toList(growable: false);
    expect(
      () => validateCampaignTaskContent(withoutDayThree),
      throwsFormatException,
    );

    final planRepair = tasks.singleWhere(
      (task) => task.id == 'task_plan_repair_05',
    );
    final oneRequiredOnDayFive = [
      for (final task in tasks)
        if (task.id == planRepair.id)
          _copyTask(task, requiredForCheckpoint: false)
        else
          task,
    ];
    expect(
      () => validateCampaignTaskContent(oneRequiredOnDayFive),
      throwsFormatException,
    );
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

  test('valid categorization parses into typed content', () {
    final task = FinancialTask.fromJson(_validCategorizationTaskJson());
    expect(task.type, 'categorization');
    expect(task.categorizationScenario.categories, hasLength(2));
    expect(task.categorizationScenario.items, hasLength(2));
    expect(task.categorizationScenario.correctAssignments, {
      'food': 'need',
      'ball': 'want',
    });
  });

  test('categorization rejects duplicate and malformed canonical fields', () {
    final invalidCases = <String, void Function(Map<String, Object?>)>{
      'duplicate category ID': (task) {
        final scenario = task['scenarioData'] as Map<String, Object?>;
        final categories = scenario['categories'] as List;
        (categories[1] as Map<String, Object?>)['id'] = 'need';
      },
      'duplicate item ID': (task) {
        final scenario = task['scenarioData'] as Map<String, Object?>;
        final items = scenario['items'] as List;
        (items[1] as Map<String, Object?>)['id'] = 'food';
      },
      'unknown item category': (task) {
        final scenario = task['scenarioData'] as Map<String, Object?>;
        final items = scenario['items'] as List;
        (items[0] as Map<String, Object?>)['correctCategoryId'] = 'other';
      },
      'empty prompt': (task) {
        final scenario = task['scenarioData'] as Map<String, Object?>;
        scenario['prompt'] = ' ';
      },
      'empty category description': (task) {
        final scenario = task['scenarioData'] as Map<String, Object?>;
        final categories = scenario['categories'] as List;
        (categories[0] as Map<String, Object?>)['description'] = '';
      },
      'empty item feedback': (task) {
        final scenario = task['scenarioData'] as Map<String, Object?>;
        final items = scenario['items'] as List;
        (items[0] as Map<String, Object?>)['feedback'] = ' ';
      },
      'empty success explanation': (task) {
        final scenario = task['scenarioData'] as Map<String, Object?>;
        scenario['successExplanation'] = '';
      },
    };
    for (final entry in invalidCases.entries) {
      final json = _validCategorizationTaskJson();
      entry.value(json);
      expect(
        () => FinancialTask.fromJson(json),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });

  test('valid budget priority parses into typed content', () {
    final task = FinancialTask.fromJson(_validBudgetPriorityTaskJson());
    expect(task.type, 'budget_priority');
    expect(task.budgetPriorityScenario.budget, 150);
    expect(task.budgetPriorityScenario.items, hasLength(3));
    expect(task.budgetPriorityScenario.correctAssignments, {
      'food': 'buy_now',
      'shampoo': 'buy_now',
      'bow': 'later',
    });
  });

  test('budget priority rejects malformed canonical fields', () {
    final invalidCases = <String, void Function(Map<String, Object?>)>{
      'zero budget': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['budget'] = 0,
      'negative budget': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['budget'] = -1,
      'empty prompt': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['prompt'] = ' ',
      'empty zone label': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['buyNowLabel'] = '',
      'duplicate item ID': (task) {
        final items =
            (task['scenarioData'] as Map<String, Object?>)['items'] as List;
        (items[1] as Map<String, Object?>)['id'] = 'food';
      },
      'zero price': (task) {
        final items =
            (task['scenarioData'] as Map<String, Object?>)['items'] as List;
        (items[0] as Map<String, Object?>)['price'] = 0;
      },
      'negative price': (task) {
        final items =
            (task['scenarioData'] as Map<String, Object?>)['items'] as List;
        (items[0] as Map<String, Object?>)['price'] = -1;
      },
      'unknown decision': (task) {
        final items =
            (task['scenarioData'] as Map<String, Object?>)['items'] as List;
        (items[0] as Map<String, Object?>)['correctDecision'] = 'unknown';
      },
      'empty feedback': (task) {
        final items =
            (task['scenarioData'] as Map<String, Object?>)['items'] as List;
        (items[0] as Map<String, Object?>)['feedback'] = ' ';
      },
      'no later item': (task) {
        final items =
            (task['scenarioData'] as Map<String, Object?>)['items'] as List;
        (items[2] as Map<String, Object?>)['correctDecision'] = 'buy_now';
      },
      'canonical buy-now total exceeds budget': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['budget'] = 149,
      'empty explanation': (task) =>
          (task['scenarioData'] as Map<String, Object?>)['successExplanation'] =
              '',
    };
    for (final entry in invalidCases.entries) {
      final json = _validBudgetPriorityTaskJson();
      entry.value(json);
      expect(
        () => FinancialTask.fromJson(json),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });

  test(
    'canonical Day 3 plan adaptation parses with a valid 20 coin remainder',
    () async {
      final tasks = await AssetContentRepository().loadTasks();
      final task = tasks.singleWhere(
        (item) => item.id == 'task_changed_plan_03',
      );
      expect(task.type, 'plan_adaptation');
      expect(task.planAdaptationScenario.isCanonicalDay3, isTrue);
      expect(task.planAdaptationScenario.canonicalKeepTotal, 200);
      expect(task.planAdaptationScenario.availableBudget, 220);
      expect(task.planAdaptationScenario.correctAssignments, {
        'food': 'keep',
        'shampoo': 'keep',
        'toy': 'later',
        'savings': 'keep',
      });
      expect(tasks.length, greaterThanOrEqualTo(6));
      expect(
        tasks.map((item) => item.topic).toSet().length,
        greaterThanOrEqualTo(3),
      );
    },
  );

  test('plan adaptation rejects malformed scenario fields', () async {
    final source = jsonDecode(
      await rootBundle.loadString('assets/content/tasks.json'),
    ) as List;
    final canonical = Map<String, Object?>.from(
      source.singleWhere((item) => item['id'] == 'task_changed_plan_03') as Map,
    );
    final invalidCases = <String, void Function(Map<String, Object?>)>{
      'unknown type': (task) => task['type'] = 'unknown',
      'missing scenario': (task) => task['scenarioData'] = null,
      'duplicate item': (task) {
        final items = (task['scenarioData'] as Map)['items'] as List;
        (items[1] as Map)['id'] = 'food';
      },
      'unknown decision': (task) {
        final items = (task['scenarioData'] as Map)['items'] as List;
        (items[0] as Map)['correctDecision'] = 'other';
      },
      'zero item price': (task) {
        final items = (task['scenarioData'] as Map)['items'] as List;
        (items[0] as Map)['price'] = 0;
      },
      'negative lost amount': (task) =>
          (task['scenarioData'] as Map)['lostAmount'] = -1,
      'zero lost amount': (task) {
        (task['scenarioData'] as Map)['lostAmount'] = 0;
        (task['scenarioData'] as Map)['availableBudget'] = 300;
      },
      'inconsistent available budget': (task) =>
          (task['scenarioData'] as Map)['availableBudget'] = 219,
    };
    for (final entry in invalidCases.entries) {
      final candidate =
          jsonDecode(jsonEncode(canonical)) as Map<String, dynamic>;
      entry.value(candidate);
      expect(
        () => FinancialTask.fromJson(candidate),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });

  test(
    'campaign keeps exactly one required categorization task on Day 1',
    () async {
      final tasks = await AssetContentRepository().loadTasks();
      final dayOneRequired = tasks.where(
        (task) => task.period == 1 && task.requiredForCheckpoint,
      );
      expect(dayOneRequired, hasLength(1));
      expect(dayOneRequired.single.id, 'task_need_or_want_01');
      expect(dayOneRequired.single.type, 'categorization');
      final dayTwoRequired = tasks.where(
        (task) => task.period == 2 && task.requiredForCheckpoint,
      );
      expect(dayTwoRequired, hasLength(1));
      expect(dayTwoRequired.single.id, 'task_priority_02');
      expect(dayTwoRequired.single.type, 'budget_priority');
      expect(() => validateCampaignTaskContent(tasks), returnsNormally);
      expect(tasks.where((task) => task.type == 'choice'), isEmpty);
      expect(tasks.where((task) => task.type == 'shopping_trip'), hasLength(1));
    },
  );
}
