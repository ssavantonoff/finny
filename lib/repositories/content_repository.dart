import 'dart:convert';

import 'package:finny/models/content_entry.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/services.dart';

abstract interface class ContentRepository {
  Future<List<FinancialTask>> loadTasks();
  Future<List<ShopItem>> loadShopItems();
  Future<List<SavingsGoal>> loadGoals();
  Future<List<PeriodDefinition>> loadPeriods();
  Future<List<GlossaryEntry>> loadGlossary();
}

class AssetContentRepository implements ContentRepository {
  AssetContentRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<List<FinancialTask>> loadTasks() =>
      _loadList('assets/content/tasks.json', FinancialTask.fromJson);

  @override
  Future<List<ShopItem>> loadShopItems() =>
      _loadList('assets/content/shop_items.json', ShopItem.fromJson);

  @override
  Future<List<SavingsGoal>> loadGoals() =>
      _loadList('assets/content/goals.json', SavingsGoal.fromJson);

  @override
  Future<List<PeriodDefinition>> loadPeriods() =>
      _loadList('assets/content/periods.json', PeriodDefinition.fromJson);

  @override
  Future<List<GlossaryEntry>> loadGlossary() =>
      _loadList('assets/content/glossary.json', GlossaryEntry.fromJson);

  Future<List<T>> _loadList<T>(
    String assetPath,
    T Function(Map<String, Object?> json) parse,
  ) async {
    final source = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! List<Object?>) {
      throw FormatException('$assetPath must contain a JSON array.');
    }
    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw FormatException('$assetPath contains a non-object entry.');
          }
          return parse(Map<String, Object?>.from(entry));
        })
        .toList(growable: false);
  }
}
