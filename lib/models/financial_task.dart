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
    required this.choiceScenario,
  });

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
  final ChoiceTaskScenario choiceScenario;

  factory FinancialTask.fromJson(Map<String, Object?> json) {
    final scenario = json['scenarioData'];
    if (scenario is! Map) {
      throw const FormatException('Choice task scenario must be an object.');
    }
    final task = FinancialTask(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      topic: _requiredString(json, 'topic'),
      description: _requiredString(json, 'description'),
      type: _requiredString(json, 'type'),
      reward: _requiredInt(json, 'reward'),
      period: _requiredInt(json, 'period'),
      requiredForCheckpoint: _requiredBool(json, 'requiredForCheckpoint'),
      choiceScenario: ChoiceTaskScenario.fromJson(
        Map<String, Object?>.from(scenario),
      ),
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
    if (type != 'choice') {
      throw FormatException('Unsupported task type: $type');
    }
    choiceScenario.validate();
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
