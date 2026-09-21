import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/models/game_period.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const adultCampaignDays = 5;

class AdultOverview {
  const AdultOverview({
    required this.completedDays,
    required this.developmentStage,
    required this.savedAmount,
  });

  final int completedDays;
  final int? developmentStage;
  final int savedAmount;
}

sealed class AdultViewState {
  const AdultViewState();
}

class AdultLoading extends AdultViewState {
  const AdultLoading();
}

class AdultNoProfile extends AdultViewState {
  const AdultNoProfile();
}

class AdultReady extends AdultViewState {
  const AdultReady(this.overview);

  final AdultOverview overview;
}

class AdultFailure extends AdultViewState {
  const AdultFailure();
}

enum AdultDataManagementOperation { reset, delete }

sealed class AdultDataManagementState {
  const AdultDataManagementState();
}

class AdultDataManagementIdle extends AdultDataManagementState {
  const AdultDataManagementIdle();
}

class AdultDataManagementRunning extends AdultDataManagementState {
  const AdultDataManagementRunning(this.operation);

  final AdultDataManagementOperation operation;
}

class AdultDataManagementFailure extends AdultDataManagementState {
  const AdultDataManagementFailure(this.operation);

  final AdultDataManagementOperation operation;
}

final adultControllerProvider =
    NotifierProvider<AdultController, AdultViewState>(AdultController.new);

final adultDataManagementControllerProvider =
    NotifierProvider<AdultDataManagementController, AdultDataManagementState>(
      AdultDataManagementController.new,
    );

class AdultController extends Notifier<AdultViewState> {
  int _generation = 0;
  bool _alive = true;

  @override
  AdultViewState build() {
    ref.onDispose(() => _alive = false);
    ref.listen<int?>(activeProfileIdProvider, (_, _) => unawaited(load()));
    return const AdultLoading();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) {
      state = const AdultNoProfile();
      return;
    }

    state = const AdultLoading();
    try {
      final games = ref.read(gameRepositoryProvider);
      final periods = await games.getPeriods(profileId);
      final pet = await games.getPet(profileId);
      final gameState = await games.getGameState(profileId);
      if (!_isCurrent(generation, profileId)) return;
      if (gameState == null) {
        state = const AdultFailure();
        return;
      }

      state = AdultReady(
        AdultOverview(
          completedDays: periods
              .where((period) => period.status == GamePeriodStatus.completed)
              .length,
          developmentStage: pet?.developmentStage,
          savedAmount: gameState.savedAmount,
        ),
      );
    } catch (_) {
      if (_isCurrent(generation, profileId)) {
        state = const AdultFailure();
      }
    }
  }

  bool _isCurrent(int generation, int profileId) =>
      _alive &&
      generation == _generation &&
      ref.read(activeProfileIdProvider) == profileId;
}

class AdultDataManagementController extends Notifier<AdultDataManagementState> {
  Future<void>? _pending;

  @override
  AdultDataManagementState build() => const AdultDataManagementIdle();

  Future<bool> resetProgress() => _run(
    AdultDataManagementOperation.reset,
    (profileId) => ref
        .read(profileDataManagementPortProvider)
        .resetNormalProfile(profileId),
  );

  Future<bool> deleteProfile() => _run(
    AdultDataManagementOperation.delete,
    (profileId) => ref
        .read(profileDataManagementPortProvider)
        .deleteNormalProfile(profileId),
  );

  Future<bool> _run(
    AdultDataManagementOperation operation,
    Future<void> Function(int profileId) action,
  ) async {
    if (_pending != null) return false;
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) {
      state = AdultDataManagementFailure(operation);
      return false;
    }

    state = AdultDataManagementRunning(operation);
    final pending = _execute(operation, profileId, action);
    _pending = pending;
    try {
      return await pending;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  Future<bool> _execute(
    AdultDataManagementOperation operation,
    int profileId,
    Future<void> Function(int profileId) action,
  ) async {
    try {
      await action(profileId);
      state = const AdultDataManagementIdle();
      return true;
    } catch (_) {
      state = AdultDataManagementFailure(operation);
      return false;
    }
  }
}
