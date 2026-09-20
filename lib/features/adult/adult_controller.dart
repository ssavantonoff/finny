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

final adultControllerProvider =
    NotifierProvider<AdultController, AdultViewState>(AdultController.new);

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
