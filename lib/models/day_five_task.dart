import 'package:finny/models/shop_item.dart';

class DayFiveTaskCompletion {
  const DayFiveTaskCompletion({
    required this.legacyCompleted,
    required this.completedTaskIds,
  });

  final bool legacyCompleted;
  final Set<String> completedTaskIds;
  int get completedCount => legacyCompleted ? 2 : completedTaskIds.length;
  int get totalCount => 2;
}

class DayFiveTaskItem {
  const DayFiveTaskItem({
    required this.id,
    required this.label,
    required this.context,
  });

  final String id;
  final String label;
  final String context;

  factory DayFiveTaskItem.fromJson(Map<String, Object?> json) =>
      DayFiveTaskItem(
        id: _string(json, 'id'),
        label: _string(json, 'label'),
        context: _string(json, 'context'),
      );
}

class DayFiveEvaluation {
  const DayFiveEvaluation({
    required this.total,
    required this.budget,
    required this.missingRequiredIds,
    required this.savingsShortfall,
  });

  final int total;
  final int budget;
  final Set<String> missingRequiredIds;
  final int savingsShortfall;

  int get overBudgetBy => total > budget ? total - budget : 0;
  int get remaining => budget - total;
  bool get isSuccess =>
      missingRequiredIds.isEmpty && savingsShortfall == 0 && overBudgetBy == 0;
}

class IndependentBudgetScenario {
  const IndependentBudgetScenario({
    required this.prompt,
    required this.budget,
    required this.minimumSavings,
    required this.items,
    required this.requiredItemIds,
    required this.successExplanation,
  });

  final String prompt;
  final int budget;
  final int minimumSavings;
  final List<DayFiveTaskItem> items;
  final Set<String> requiredItemIds;
  final String successExplanation;

  factory IndependentBudgetScenario.fromJson(Map<String, Object?> json) =>
      IndependentBudgetScenario(
        prompt: _string(json, 'prompt'),
        budget: _int(json, 'budget'),
        minimumSavings: _int(json, 'minimumSavings'),
        items: _items(json),
        requiredItemIds: _ids(json, 'requiredItemIds'),
        successExplanation: _string(json, 'successExplanation'),
      );

  void validate() {
    if (prompt.trim().isEmpty ||
        successExplanation.trim().isEmpty ||
        budget != 350 ||
        minimumSavings != 50 ||
        !_sameIds(items.map((item) => item.id).toSet(), {
          'food_feed',
          'care_comb',
          'toy_ball',
          'accessory_bow',
        }) ||
        !_sameIds(requiredItemIds, {'food_feed', 'care_comb'})) {
      throw const FormatException('Invalid Day 5 independent budget scenario.');
    }
    _validateItems(items);
  }

  bool isValidSubmission(Set<String> selectedIds, int savingsAmount) =>
      savingsAmount >= 0 &&
      savingsAmount % 10 == 0 &&
      selectedIds.every((id) => items.any((item) => item.id == id));

  DayFiveEvaluation evaluate(
    Set<String> selectedIds,
    int savingsAmount,
    List<ShopItem> catalog,
  ) {
    if (!isValidSubmission(selectedIds, savingsAmount)) {
      throw ArgumentError('Invalid independent budget submission.');
    }
    final prices = _canonicalPrices(catalog, items.map((item) => item.id));
    final total = selectedIds.fold<int>(
      savingsAmount,
      (sum, id) => sum + prices[id]!,
    );
    return DayFiveEvaluation(
      total: total,
      budget: budget,
      missingRequiredIds: requiredItemIds.difference(selectedIds),
      savingsShortfall: savingsAmount >= minimumSavings
          ? 0
          : minimumSavings - savingsAmount,
    );
  }

  bool isValidStoredState(Map<String, Object?> state, List<ShopItem> catalog) {
    final parsed = _storedSelection(state, 'independent_budget');
    if (parsed == null || !isValidSubmission(parsed.ids, parsed.savings)) {
      return false;
    }
    return evaluate(parsed.ids, parsed.savings, catalog).isSuccess;
  }
}

class PlanRepairScenario {
  const PlanRepairScenario({
    required this.prompt,
    required this.event,
    required this.budget,
    required this.initialSavings,
    required this.minimumSavings,
    required this.items,
    required this.requiredNowIds,
    required this.scenarioExpenseId,
    required this.scenarioExpensePrice,
    required this.successExplanation,
  });

  final String prompt;
  final String event;
  final int budget;
  final int initialSavings;
  final int minimumSavings;
  final List<DayFiveTaskItem> items;
  final Set<String> requiredNowIds;
  final String scenarioExpenseId;
  final int scenarioExpensePrice;
  final String successExplanation;

  factory PlanRepairScenario.fromJson(Map<String, Object?> json) =>
      PlanRepairScenario(
        prompt: _string(json, 'prompt'),
        event: _string(json, 'event'),
        budget: _int(json, 'budget'),
        initialSavings: _int(json, 'initialSavings'),
        minimumSavings: _int(json, 'minimumSavings'),
        items: _items(json),
        requiredNowIds: _ids(json, 'requiredNowIds'),
        scenarioExpenseId: _string(json, 'scenarioExpenseId'),
        scenarioExpensePrice: _int(json, 'scenarioExpensePrice'),
        successExplanation: _string(json, 'successExplanation'),
      );

  Set<String> get initialNowIds => items.map((item) => item.id).toSet();

  void validate() {
    if (prompt.trim().isEmpty ||
        event.trim().isEmpty ||
        successExplanation.trim().isEmpty ||
        budget != 350 ||
        initialSavings != 70 ||
        minimumSavings != 10 ||
        scenarioExpenseId != 'scenario_waterer_05' ||
        scenarioExpensePrice != 60 ||
        !_sameIds(items.map((item) => item.id).toSet(), {
          'food_feed',
          'care_comb',
          'toy_ball',
          'scenario_waterer_05',
        }) ||
        !_sameIds(requiredNowIds, {
          'food_feed',
          'care_comb',
          'scenario_waterer_05',
        })) {
      throw const FormatException('Invalid Day 5 plan repair scenario.');
    }
    _validateItems(items);
  }

  bool isValidSubmission(Set<String> nowIds, int savingsAmount) =>
      savingsAmount >= 0 &&
      savingsAmount % 10 == 0 &&
      nowIds.every((id) => items.any((item) => item.id == id));

  DayFiveEvaluation evaluate(
    Set<String> nowIds,
    int savingsAmount,
    List<ShopItem> catalog,
  ) {
    if (!isValidSubmission(nowIds, savingsAmount)) {
      throw ArgumentError('Invalid plan repair submission.');
    }
    final prices = _canonicalPrices(
      catalog,
      items.map((item) => item.id).where((id) => id != scenarioExpenseId),
    );
    final total = nowIds.fold<int>(
      savingsAmount,
      (sum, id) =>
          sum + (id == scenarioExpenseId ? scenarioExpensePrice : prices[id]!),
    );
    return DayFiveEvaluation(
      total: total,
      budget: budget,
      missingRequiredIds: requiredNowIds.difference(nowIds),
      savingsShortfall: savingsAmount >= minimumSavings
          ? 0
          : minimumSavings - savingsAmount,
    );
  }

  bool isValidStoredState(Map<String, Object?> state, List<ShopItem> catalog) {
    final parsed = _storedSelection(state, 'plan_repair');
    if (parsed == null || !isValidSubmission(parsed.ids, parsed.savings)) {
      return false;
    }
    return evaluate(parsed.ids, parsed.savings, catalog).isSuccess;
  }
}

({Set<String> ids, int savings})? _storedSelection(
  Map<String, Object?> state,
  String type,
) {
  if (state.length != 3 ||
      state['type'] != type ||
      state['selectedItemIds'] is! List ||
      state['savingsAmount'] is! int) {
    return null;
  }
  final raw = state['selectedItemIds'] as List;
  if (raw.any((id) => id is! String)) return null;
  final ids = raw.cast<String>().toSet();
  if (ids.length != raw.length) return null;
  return (ids: ids, savings: state['savingsAmount'] as int);
}

Map<String, int> _canonicalPrices(
  List<ShopItem> catalog,
  Iterable<String> ids,
) {
  final prices = <String, int>{};
  for (final id in ids) {
    final matches = catalog.where(
      (item) => item.id == id && item.unlockType == 'available',
    );
    if (matches.length != 1 || matches.single.price <= 0) {
      throw StateError('Missing canonical shop item $id.');
    }
    prices[id] = matches.single.price;
  }
  return prices;
}

void _validateItems(List<DayFiveTaskItem> items) {
  if (items.map((item) => item.id).toSet().length != items.length ||
      items.any(
        (item) =>
            item.id.trim().isEmpty ||
            item.label.trim().isEmpty ||
            item.context.trim().isEmpty,
      )) {
    throw const FormatException('Invalid Day 5 task items.');
  }
}

bool _sameIds(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

List<DayFiveTaskItem> _items(Map<String, Object?> json) {
  final value = json['items'];
  if (value is! List) throw const FormatException('items must be a list.');
  return value
      .map((entry) {
        if (entry is! Map) {
          throw const FormatException('item must be an object.');
        }
        return DayFiveTaskItem.fromJson(Map<String, Object?>.from(entry));
      })
      .toList(growable: false);
}

Set<String> _ids(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be a string list.');
  }
  final ids = value.cast<String>().toSet();
  if (ids.length != value.length) throw FormatException('$key has duplicates.');
  return ids;
}
