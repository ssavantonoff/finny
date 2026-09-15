class FinancialTask {
  const FinancialTask({
    required this.id,
    required this.title,
    required this.topic,
    required this.description,
    required this.type,
    required this.reward,
    required this.period,
    required this.scenarioData,
  });

  final String id;
  final String title;
  final String topic;
  final String description;
  final String type;
  final int reward;
  final int period;
  final Map<String, Object?> scenarioData;

  factory FinancialTask.fromJson(Map<String, Object?> json) => FinancialTask(
    id: json['id'] as String,
    title: json['title'] as String,
    topic: json['topic'] as String,
    description: json['description'] as String,
    type: json['type'] as String,
    reward: json['reward'] as int,
    period: json['period'] as int,
    scenarioData: Map<String, Object?>.from(
      (json['scenarioData'] as Map?) ?? const <String, Object?>{},
    ),
  );
}
