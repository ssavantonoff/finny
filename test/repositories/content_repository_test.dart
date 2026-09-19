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
      choiceScenario: task.choiceScenario,
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
    expect(dayOne.choiceScenario.options.map((option) => option.id), [
      'apple',
      'ball',
      'decoration',
    ]);
    expect(dayOne.choiceScenario.correctOptionId, 'apple');
    expect(dayOne.choiceScenario.explanation, isNotEmpty);
    expect(tasks.where((task) => task.requiredForCheckpoint), hasLength(5));
    expect(
      tasks
          .singleWhere((task) => task.id == 'task_bonus_reserve_05')
          .requiredForCheckpoint,
      isFalse,
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
        promotions.single.checkpoint,
      ),
      ('day4_treat_discount', 4, 'food_treat', 35, 1, 'discount_decision'),
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
            'Лакомство',
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
            'Расчёска',
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
            'Плюшевая игрушка',
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
            'Бантик',
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
            'Ошейник',
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
            'Шапочка',
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
        checkpoint: 'discount_decision',
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
              checkpoint: 'discount_decision',
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
              checkpoint: 'discount_decision',
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
              checkpoint: 'discount_decision',
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

  test(
    'campaign requires exactly one required task on each of five days',
    () async {
      final tasks = await AssetContentRepository().loadTasks();
      expect(() => validateCampaignTaskContent(tasks), returnsNormally);

      final withoutDayThree = tasks
          .where((task) => task.period != 3)
          .toList(growable: false);
      expect(
        () => validateCampaignTaskContent(withoutDayThree),
        throwsFormatException,
      );

      final bonus = tasks.singleWhere(
        (task) => task.id == 'task_bonus_reserve_05',
      );
      final twoRequiredOnDayFive = [
        for (final task in tasks)
          if (task.id == bonus.id)
            _copyTask(task, requiredForCheckpoint: true)
          else
            task,
      ];
      expect(
        () => validateCampaignTaskContent(twoRequiredOnDayFive),
        throwsFormatException,
      );
    },
  );

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
