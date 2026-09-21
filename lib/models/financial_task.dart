class ChoiceTaskOption {
  const ChoiceTaskOption({required this.id, required this.label});

  final String id;
  final String label;

  factory ChoiceTaskOption.fromJson(Map<String, Object?> json) =>
      ChoiceTaskOption(
        id: _requiredString(json, 'id'),
        label: _requiredString(json, 'label'),
      );
}

class ChoiceTaskScenario {
  const ChoiceTaskScenario({
    required this.prompt,
    required this.options,
    required this.correctOptionId,
    required this.explanation,
  });

  final String prompt;
  final List<ChoiceTaskOption> options;
  final String correctOptionId;
  final String explanation;

  factory ChoiceTaskScenario.fromJson(Map<String, Object?> json) {
    final options = json['options'];
    if (options is! List) {
      throw const FormatException('Choice task options must be a list.');
    }
    return ChoiceTaskScenario(
      prompt: _requiredString(json, 'prompt'),
      options: options
          .map((value) {
            if (value is! Map) {
              throw const FormatException(
                'Choice task option must be an object.',
              );
            }
            return ChoiceTaskOption.fromJson(Map<String, Object?>.from(value));
          })
          .toList(growable: false),
      correctOptionId: _requiredString(json, 'correctOptionId'),
      explanation: _requiredString(json, 'explanation'),
    );
  }

  void validate() {
    if (prompt.trim().isEmpty || explanation.trim().isEmpty) {
      throw const FormatException('Choice task text must not be empty.');
    }
    if (options.length < 2) {
      throw const FormatException('Choice task needs at least two options.');
    }
    final ids = <String>{};
    for (final option in options) {
      if (option.id.trim().isEmpty || option.label.trim().isEmpty) {
        throw const FormatException('Choice option ID and label are required.');
      }
      if (!ids.add(option.id)) {
        throw FormatException('Duplicate choice option ID: ${option.id}');
      }
    }
    if (correctOptionId.trim().isEmpty || !ids.contains(correctOptionId)) {
      throw const FormatException('Choice task correct option is invalid.');
    }
  }
}

class CategorizationTaskCategory {
  const CategorizationTaskCategory({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  factory CategorizationTaskCategory.fromJson(Map<String, Object?> json) =>
      CategorizationTaskCategory(
        id: _requiredString(json, 'id'),
        label: _requiredString(json, 'label'),
        description: _requiredString(json, 'description'),
      );
}

class CategorizationTaskItem {
  const CategorizationTaskItem({
    required this.id,
    required this.label,
    required this.correctCategoryId,
    required this.feedback,
  });

  final String id;
  final String label;
  final String correctCategoryId;
  final String feedback;

  factory CategorizationTaskItem.fromJson(Map<String, Object?> json) =>
      CategorizationTaskItem(
        id: _requiredString(json, 'id'),
        label: _requiredString(json, 'label'),
        correctCategoryId: _requiredString(json, 'correctCategoryId'),
        feedback: _requiredString(json, 'feedback'),
      );
}

class CategorizationTaskScenario {
  const CategorizationTaskScenario({
    required this.prompt,
    required this.categories,
    required this.items,
    required this.successExplanation,
  });

  final String prompt;
  final List<CategorizationTaskCategory> categories;
  final List<CategorizationTaskItem> items;
  final String successExplanation;

  factory CategorizationTaskScenario.fromJson(Map<String, Object?> json) {
    final categories = json['categories'];
    final items = json['items'];
    if (categories is! List) {
      throw const FormatException(
        'Categorization task categories must be a list.',
      );
    }
    if (items is! List) {
      throw const FormatException('Categorization task items must be a list.');
    }
    return CategorizationTaskScenario(
      prompt: _requiredString(json, 'prompt'),
      categories: categories
          .map((value) {
            if (value is! Map) {
              throw const FormatException(
                'Categorization task category must be an object.',
              );
            }
            return CategorizationTaskCategory.fromJson(
              Map<String, Object?>.from(value),
            );
          })
          .toList(growable: false),
      items: items
          .map((value) {
            if (value is! Map) {
              throw const FormatException(
                'Categorization task item must be an object.',
              );
            }
            return CategorizationTaskItem.fromJson(
              Map<String, Object?>.from(value),
            );
          })
          .toList(growable: false),
      successExplanation: _requiredString(json, 'successExplanation'),
    );
  }

  Map<String, String> get correctAssignments => {
    for (final item in items) item.id: item.correctCategoryId,
  };

  void validate() {
    if (prompt.trim().isEmpty || successExplanation.trim().isEmpty) {
      throw const FormatException(
        'Categorization task text must not be empty.',
      );
    }
    if (categories.length < 2) {
      throw const FormatException(
        'Categorization task needs at least two categories.',
      );
    }
    final categoryIds = <String>{};
    for (final category in categories) {
      if (category.id.trim().isEmpty ||
          category.label.trim().isEmpty ||
          category.description.trim().isEmpty) {
        throw const FormatException(
          'Categorization category ID, label and description are required.',
        );
      }
      if (!categoryIds.add(category.id)) {
        throw FormatException(
          'Duplicate categorization category ID: ${category.id}',
        );
      }
    }
    if (items.length < 2) {
      throw const FormatException(
        'Categorization task needs at least two items.',
      );
    }
    final itemIds = <String>{};
    for (final item in items) {
      if (item.id.trim().isEmpty ||
          item.label.trim().isEmpty ||
          item.correctCategoryId.trim().isEmpty ||
          item.feedback.trim().isEmpty) {
        throw const FormatException(
          'Categorization item ID, label, category and feedback are required.',
        );
      }
      if (!itemIds.add(item.id)) {
        throw FormatException('Duplicate categorization item ID: ${item.id}');
      }
      if (!categoryIds.contains(item.correctCategoryId)) {
        throw FormatException(
          'Unknown category ${item.correctCategoryId} for item ${item.id}.',
        );
      }
    }
  }
}

enum BudgetPriorityDecision {
  buyNow('buy_now'),
  later('later');

  const BudgetPriorityDecision(this.wireValue);

  final String wireValue;

  factory BudgetPriorityDecision.fromJson(String value) =>
      BudgetPriorityDecision.values.firstWhere(
        (decision) => decision.wireValue == value,
        orElse: () => throw FormatException(
          'Unsupported budget priority decision: $value',
        ),
      );
}

class BudgetPriorityTaskItem {
  const BudgetPriorityTaskItem({
    required this.id,
    required this.label,
    required this.price,
    required this.correctDecision,
    required this.feedback,
  });

  final String id;
  final String label;
  final int price;
  final BudgetPriorityDecision correctDecision;
  final String feedback;

  factory BudgetPriorityTaskItem.fromJson(Map<String, Object?> json) =>
      BudgetPriorityTaskItem(
        id: _requiredString(json, 'id'),
        label: _requiredString(json, 'label'),
        price: _requiredInt(json, 'price'),
        correctDecision: BudgetPriorityDecision.fromJson(
          _requiredString(json, 'correctDecision'),
        ),
        feedback: _requiredString(json, 'feedback'),
      );
}

class BudgetPriorityTaskScenario {
  const BudgetPriorityTaskScenario({
    required this.prompt,
    required this.budget,
    required this.buyNowLabel,
    required this.buyNowDescription,
    required this.laterLabel,
    required this.laterDescription,
    required this.items,
    required this.incorrectExplanation,
    required this.successExplanation,
  });

  final String prompt;
  final int budget;
  final String buyNowLabel;
  final String buyNowDescription;
  final String laterLabel;
  final String laterDescription;
  final List<BudgetPriorityTaskItem> items;
  final String incorrectExplanation;
  final String successExplanation;

  factory BudgetPriorityTaskScenario.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Budget priority items must be a list.');
    }
    return BudgetPriorityTaskScenario(
      prompt: _requiredString(json, 'prompt'),
      budget: _requiredInt(json, 'budget'),
      buyNowLabel: _requiredString(json, 'buyNowLabel'),
      buyNowDescription: _requiredString(json, 'buyNowDescription'),
      laterLabel: _requiredString(json, 'laterLabel'),
      laterDescription: _requiredString(json, 'laterDescription'),
      items: items
          .map((value) {
            if (value is! Map) {
              throw const FormatException(
                'Budget priority item must be an object.',
              );
            }
            return BudgetPriorityTaskItem.fromJson(
              Map<String, Object?>.from(value),
            );
          })
          .toList(growable: false),
      incorrectExplanation: _requiredString(json, 'incorrectExplanation'),
      successExplanation: _requiredString(json, 'successExplanation'),
    );
  }

  Map<String, String> get correctAssignments => {
    for (final item in items) item.id: item.correctDecision.wireValue,
  };

  void validate() {
    if (prompt.trim().isEmpty ||
        buyNowLabel.trim().isEmpty ||
        buyNowDescription.trim().isEmpty ||
        laterLabel.trim().isEmpty ||
        laterDescription.trim().isEmpty ||
        incorrectExplanation.trim().isEmpty ||
        successExplanation.trim().isEmpty) {
      throw const FormatException(
        'Budget priority task text must not be empty.',
      );
    }
    if (budget <= 0) {
      throw const FormatException('Budget priority budget must be positive.');
    }
    if (items.length < 2) {
      throw const FormatException(
        'Budget priority task needs at least two items.',
      );
    }
    final itemIds = <String>{};
    var hasBuyNow = false;
    var hasLater = false;
    var correctBuyNowTotal = 0;
    for (final item in items) {
      if (item.id.trim().isEmpty ||
          item.label.trim().isEmpty ||
          item.feedback.trim().isEmpty) {
        throw const FormatException(
          'Budget priority item ID, label and feedback are required.',
        );
      }
      if (item.price <= 0) {
        throw const FormatException(
          'Budget priority item price must be positive.',
        );
      }
      if (!itemIds.add(item.id)) {
        throw FormatException('Duplicate budget priority item ID: ${item.id}');
      }
      switch (item.correctDecision) {
        case BudgetPriorityDecision.buyNow:
          hasBuyNow = true;
          correctBuyNowTotal += item.price;
          break;
        case BudgetPriorityDecision.later:
          hasLater = true;
          break;
      }
    }
    if (!hasBuyNow || !hasLater) {
      throw const FormatException(
        'Budget priority solution needs buy-now and later items.',
      );
    }
    if (correctBuyNowTotal > budget) {
      throw const FormatException(
        'Budget priority canonical solution exceeds its budget.',
      );
    }
  }
}

enum PlanAdaptationDecision {
  keep('keep'),
  later('later');

  const PlanAdaptationDecision(this.wireValue);

  final String wireValue;

  factory PlanAdaptationDecision.fromJson(String value) =>
      PlanAdaptationDecision.values.firstWhere(
        (decision) => decision.wireValue == value,
        orElse: () => throw FormatException(
          'Unsupported plan adaptation decision: $value',
        ),
      );
}

class PlanAdaptationTaskItem {
  const PlanAdaptationTaskItem({
    required this.id,
    required this.label,
    required this.price,
    required this.category,
    required this.correctDecision,
    required this.feedback,
  });

  final String id;
  final String label;
  final int price;
  final String category;
  final PlanAdaptationDecision correctDecision;
  final String feedback;

  factory PlanAdaptationTaskItem.fromJson(Map<String, Object?> json) =>
      PlanAdaptationTaskItem(
        id: _requiredString(json, 'id'),
        label: _requiredString(json, 'label'),
        price: _requiredInt(json, 'price'),
        category: _requiredString(json, 'category'),
        correctDecision: PlanAdaptationDecision.fromJson(
          _requiredString(json, 'correctDecision'),
        ),
        feedback: _requiredString(json, 'feedback'),
      );
}

class PlanAdaptationTaskScenario {
  const PlanAdaptationTaskScenario({
    required this.prompt,
    required this.originalPlan,
    required this.lostAmount,
    required this.availableBudget,
    required this.keepLabel,
    required this.keepDescription,
    required this.laterLabel,
    required this.laterDescription,
    required this.items,
    required this.incorrectExplanation,
    required this.successExplanation,
  });

  final String prompt;
  final int originalPlan;
  final int lostAmount;
  final int availableBudget;
  final String keepLabel;
  final String keepDescription;
  final String laterLabel;
  final String laterDescription;
  final List<PlanAdaptationTaskItem> items;
  final String incorrectExplanation;
  final String successExplanation;

  factory PlanAdaptationTaskScenario.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Plan adaptation items must be a list.');
    }
    return PlanAdaptationTaskScenario(
      prompt: _requiredString(json, 'prompt'),
      originalPlan: _requiredInt(json, 'originalPlan'),
      lostAmount: _requiredInt(json, 'lostAmount'),
      availableBudget: _requiredInt(json, 'availableBudget'),
      keepLabel: _requiredString(json, 'keepLabel'),
      keepDescription: _requiredString(json, 'keepDescription'),
      laterLabel: _requiredString(json, 'laterLabel'),
      laterDescription: _requiredString(json, 'laterDescription'),
      items: items
          .map((value) {
            if (value is! Map) {
              throw const FormatException(
                'Plan adaptation item must be an object.',
              );
            }
            return PlanAdaptationTaskItem.fromJson(
              Map<String, Object?>.from(value),
            );
          })
          .toList(growable: false),
      incorrectExplanation: _requiredString(json, 'incorrectExplanation'),
      successExplanation: _requiredString(json, 'successExplanation'),
    );
  }

  Map<String, String> get correctAssignments => {
    for (final item in items) item.id: item.correctDecision.wireValue,
  };

  int get canonicalKeepTotal => items
      .where((item) => item.correctDecision == PlanAdaptationDecision.keep)
      .fold<int>(0, (total, item) => total + item.price);

  bool get isCanonicalDay3 =>
      originalPlan == 300 &&
      lostAmount == 80 &&
      availableBudget == 220 &&
      items.length == 4 &&
      _matchesCanonicalItem(
        id: 'food',
        price: 90,
        category: 'need',
        decision: PlanAdaptationDecision.keep,
      ) &&
      _matchesCanonicalItem(
        id: 'shampoo',
        price: 60,
        category: 'need',
        decision: PlanAdaptationDecision.keep,
      ) &&
      _matchesCanonicalItem(
        id: 'toy',
        price: 100,
        category: 'want',
        decision: PlanAdaptationDecision.later,
      ) &&
      _matchesCanonicalItem(
        id: 'savings',
        price: 50,
        category: 'savings',
        decision: PlanAdaptationDecision.keep,
      );

  bool _matchesCanonicalItem({
    required String id,
    required int price,
    required String category,
    required PlanAdaptationDecision decision,
  }) {
    final matches = items.where((item) => item.id == id).toList();
    return matches.length == 1 &&
        matches.single.price == price &&
        matches.single.category == category &&
        matches.single.correctDecision == decision;
  }

  void validate() {
    if (prompt.trim().isEmpty ||
        keepLabel.trim().isEmpty ||
        keepDescription.trim().isEmpty ||
        laterLabel.trim().isEmpty ||
        laterDescription.trim().isEmpty ||
        incorrectExplanation.trim().isEmpty ||
        successExplanation.trim().isEmpty) {
      throw const FormatException(
        'Plan adaptation task text must not be empty.',
      );
    }
    if (originalPlan <= 0 ||
        lostAmount <= 0 ||
        availableBudget <= 0 ||
        originalPlan - lostAmount != availableBudget) {
      throw const FormatException('Plan adaptation budget values are invalid.');
    }
    if (items.length < 2) {
      throw const FormatException(
        'Plan adaptation task needs at least two items.',
      );
    }
    final itemIds = <String>{};
    for (final item in items) {
      if (item.id.trim().isEmpty ||
          item.label.trim().isEmpty ||
          item.category.trim().isEmpty ||
          item.feedback.trim().isEmpty ||
          item.price <= 0) {
        throw const FormatException(
          'Plan adaptation item fields must be valid.',
        );
      }
      if (!itemIds.add(item.id)) {
        throw FormatException('Duplicate plan adaptation item ID: ${item.id}');
      }
      if (!const {'need', 'want', 'savings'}.contains(item.category)) {
        throw FormatException(
          'Unknown plan adaptation category: ${item.category}',
        );
      }
    }
    if (!items.any((item) => item.category == 'need') ||
        !items.any((item) => item.category == 'want') ||
        !items.any((item) => item.category == 'savings')) {
      throw const FormatException(
        'Plan adaptation needs need, want and savings items.',
      );
    }
    final originalItemsTotal = items.fold<int>(
      0,
      (total, item) => total + item.price,
    );
    if (originalItemsTotal != originalPlan) {
      throw const FormatException(
        'Plan adaptation items must match the original plan.',
      );
    }
    if (canonicalKeepTotal > availableBudget) {
      throw const FormatException(
        'Plan adaptation canonical solution exceeds available budget.',
      );
    }
  }
}

class FinancialTask {
  const FinancialTask({
    required this.id,
    required this.title,
    required this.topic,
    required this.description,
    required this.type,
    required this.reward,
    required this.period,
    this.requiredForCheckpoint = true,
    ChoiceTaskScenario? choiceScenario,
    CategorizationTaskScenario? categorizationScenario,
    BudgetPriorityTaskScenario? budgetPriorityScenario,
    PlanAdaptationTaskScenario? planAdaptationScenario,
  }) : // The public parameter names preserve the existing choice constructor.
       // ignore: prefer_initializing_formals
       _choiceScenario = choiceScenario,
       // ignore: prefer_initializing_formals
       _categorizationScenario = categorizationScenario,
       // ignore: prefer_initializing_formals
       _budgetPriorityScenario = budgetPriorityScenario,
       // ignore: prefer_initializing_formals
       _planAdaptationScenario = planAdaptationScenario;

  // Stable identity: a new period, reward, correct answer, or task meaning
  // requires a new ID rather than reusing persisted task progress.
  final String id;
  final String title;
  final String topic;
  final String description;
  final String type;
  final int reward;
  final int period;
  final bool requiredForCheckpoint;
  final ChoiceTaskScenario? _choiceScenario;
  final CategorizationTaskScenario? _categorizationScenario;
  final BudgetPriorityTaskScenario? _budgetPriorityScenario;
  final PlanAdaptationTaskScenario? _planAdaptationScenario;

  ChoiceTaskScenario get choiceScenario =>
      _choiceScenario ?? (throw StateError('Task $id is not a choice task.'));

  CategorizationTaskScenario get categorizationScenario =>
      _categorizationScenario ??
      (throw StateError('Task $id is not a categorization task.'));

  BudgetPriorityTaskScenario get budgetPriorityScenario =>
      _budgetPriorityScenario ??
      (throw StateError('Task $id is not a budget priority task.'));

  PlanAdaptationTaskScenario get planAdaptationScenario =>
      _planAdaptationScenario ??
      (throw StateError('Task $id is not a plan adaptation task.'));

  factory FinancialTask.fromJson(Map<String, Object?> json) {
    final scenario = json['scenarioData'];
    if (scenario is! Map) {
      throw const FormatException('Choice task scenario must be an object.');
    }
    final type = _requiredString(json, 'type');
    final task = FinancialTask(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      topic: _requiredString(json, 'topic'),
      description: _requiredString(json, 'description'),
      type: type,
      reward: _requiredInt(json, 'reward'),
      period: _requiredInt(json, 'period'),
      requiredForCheckpoint: _requiredBool(json, 'requiredForCheckpoint'),
      choiceScenario: type == 'choice'
          ? ChoiceTaskScenario.fromJson(Map<String, Object?>.from(scenario))
          : null,
      categorizationScenario: type == 'categorization'
          ? CategorizationTaskScenario.fromJson(
              Map<String, Object?>.from(scenario),
            )
          : null,
      budgetPriorityScenario: type == 'budget_priority'
          ? BudgetPriorityTaskScenario.fromJson(
              Map<String, Object?>.from(scenario),
            )
          : null,
      planAdaptationScenario: type == 'plan_adaptation'
          ? PlanAdaptationTaskScenario.fromJson(
              Map<String, Object?>.from(scenario),
            )
          : null,
    );
    task.validate();
    return task;
  }

  void validate() {
    if (id.trim().isEmpty || title.trim().isEmpty || type.trim().isEmpty) {
      throw const FormatException('Task ID, title and type are required.');
    }
    if (period <= 0 || reward <= 0) {
      throw const FormatException('Task period and reward must be positive.');
    }
    switch (type) {
      case 'choice':
        if (_choiceScenario == null ||
            _categorizationScenario != null ||
            _budgetPriorityScenario != null ||
            _planAdaptationScenario != null) {
          throw const FormatException('Choice task scenario is invalid.');
        }
        _choiceScenario.validate();
        break;
      case 'categorization':
        if (_categorizationScenario == null ||
            _choiceScenario != null ||
            _budgetPriorityScenario != null ||
            _planAdaptationScenario != null) {
          throw const FormatException(
            'Categorization task scenario is invalid.',
          );
        }
        _categorizationScenario.validate();
        break;
      case 'budget_priority':
        if (_budgetPriorityScenario == null ||
            _choiceScenario != null ||
            _categorizationScenario != null ||
            _planAdaptationScenario != null) {
          throw const FormatException(
            'Budget priority task scenario is invalid.',
          );
        }
        _budgetPriorityScenario.validate();
        break;
      case 'plan_adaptation':
        if (_planAdaptationScenario == null ||
            _choiceScenario != null ||
            _categorizationScenario != null ||
            _budgetPriorityScenario != null) {
          throw const FormatException(
            'Plan adaptation task scenario is invalid.',
          );
        }
        _planAdaptationScenario.validate();
        break;
      default:
        throw FormatException('Unsupported task type: $type');
    }
  }
}

void validateTaskContent(List<FinancialTask> tasks) {
  final ids = <String>{};
  for (final task in tasks) {
    task.validate();
    if (!ids.add(task.id)) {
      throw FormatException('Duplicate task ID: ${task.id}');
    }
  }
}

void validateCampaignTaskContent(List<FinancialTask> tasks) {
  validateTaskContent(tasks);
  if (tasks.length < 6) {
    throw const FormatException('Campaign needs at least six tasks.');
  }
  if (tasks.map((task) => task.topic).toSet().length < 3) {
    throw const FormatException('Campaign needs at least three task topics.');
  }
  for (var day = 1; day <= 5; day++) {
    final required = tasks.where(
      (task) => task.period == day && task.requiredForCheckpoint,
    );
    if (required.length != 1) {
      throw FormatException('Day $day must have exactly one required task.');
    }
  }
  if (tasks.any((task) => task.period < 1 || task.period > 5)) {
    throw const FormatException('Campaign task period must be from 1 to 5.');
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}
