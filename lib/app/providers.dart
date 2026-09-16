import 'dart:async';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/pet_progress_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeProfileIdProvider =
    NotifierProvider<ActiveProfileIdController, int?>(
      ActiveProfileIdController.new,
    );

class ActiveProfileIdController extends Notifier<int?> {
  @override
  int? build() => null;

  void setActiveProfileId(int profileId) {
    if (profileId <= 0) {
      throw ArgumentError.value(profileId, 'profileId', 'Must be positive.');
    }
    state = profileId;
  }

  void clear() => state = null;
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SqliteProfileRepository(ref.watch(appDatabaseProvider)),
);

final gameRepositoryProvider = Provider<GameRepository>(
  (ref) => SqliteGameRepository(ref.watch(appDatabaseProvider)),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => AssetContentRepository(),
);

final budgetServiceProvider = Provider<BudgetService>(
  (ref) => BudgetService(ref.watch(gameRepositoryProvider)),
);

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => PurchaseService(ref.watch(gameRepositoryProvider)),
);

final savingsServiceProvider = Provider<SavingsService>(
  (ref) => SavingsService(ref.watch(gameRepositoryProvider)),
);

final periodServiceProvider = Provider<PeriodService>(
  (ref) => PeriodService(ref.watch(gameRepositoryProvider)),
);

final taskServiceProvider = Provider<TaskService>(
  (ref) => TaskService(ref.watch(gameRepositoryProvider)),
);

final petProgressServiceProvider = Provider<PetProgressService>(
  (ref) => PetProgressService(ref.watch(gameRepositoryProvider)),
);
