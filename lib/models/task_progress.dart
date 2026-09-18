import 'dart:convert';

enum TaskProgressStatus { completed }

class TaskProgress {
  const TaskProgress({
    required this.profileId,
    required this.taskId,
    required this.status,
    required this.rewardClaimed,
    required this.scenarioState,
    required this.updatedAt,
  });

  final int profileId;
  final String taskId;
  final TaskProgressStatus status;
  final bool rewardClaimed;
  final Map<String, Object?> scenarioState;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'profile_id': profileId,
    'task_id': taskId,
    'status': status.name,
    'reward_claimed': rewardClaimed ? 1 : 0,
    'scenario_state': jsonEncode(scenarioState),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory TaskProgress.fromMap(Map<String, Object?> map) {
    try {
      final status = TaskProgressStatus.values.firstWhere(
        (value) => value.name == map['status'],
      );
      final decoded = jsonDecode(map['scenario_state'] as String);
      if (decoded is! Map) {
        throw const FormatException('Task scenario state must be an object.');
      }
      return TaskProgress(
        profileId: map['profile_id'] as int,
        taskId: map['task_id'] as String,
        status: status,
        rewardClaimed: map['reward_claimed'] == 1,
        scenarioState: Map<String, Object?>.from(decoded),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    } catch (error) {
      throw FormatException('Malformed task progress: $error');
    }
  }
}
