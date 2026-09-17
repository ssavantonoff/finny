import 'package:finny/app/providers.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class HomeViewState {
  const HomeViewState();
}

class HomeLoading extends HomeViewState {
  const HomeLoading();
}

class HomeNeedsBootstrap extends HomeViewState {
  const HomeNeedsBootstrap();
}

class HomeFailure extends HomeViewState {
  const HomeFailure();
}

class HomeReady extends HomeViewState {
  const HomeReady({
    required this.profile,
    required this.pet,
    required this.gameState,
    required this.period,
    required this.definition,
    required this.completedDays,
    required this.allDaysCompleted,
    this.startingDay = false,
    this.startFailed = false,
    this.finishingDay = false,
    this.finishFailed = false,
  });

  final Profile profile;
  final Pet pet;
  final GameState gameState;
  final GamePeriod? period;
  final PeriodDefinition? definition;
  final int completedDays;
  final bool allDaysCompleted;
  final bool startingDay;
  final bool startFailed;
  final bool finishingDay;
  final bool finishFailed;

  HomeReady copyWith({
    bool? startingDay,
    bool? startFailed,
    bool? finishingDay,
    bool? finishFailed,
  }) => HomeReady(
    profile: profile,
    pet: pet,
    gameState: gameState,
    period: period,
    definition: definition,
    completedDays: completedDays,
    allDaysCompleted: allDaysCompleted,
    startingDay: startingDay ?? this.startingDay,
    startFailed: startFailed ?? this.startFailed,
    finishingDay: finishingDay ?? this.finishingDay,
    finishFailed: finishFailed ?? this.finishFailed,
  );
}

final homeControllerProvider = NotifierProvider<HomeController, HomeViewState>(
  HomeController.new,
);

class HomeController extends Notifier<HomeViewState> {
  int _loadGeneration = 0;
  bool _startingDay = false;
  bool _finishingDay = false;

  @override
  HomeViewState build() => const HomeLoading();

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = const HomeLoading();
    final loaded = await _readSnapshot();
    if (generation == _loadGeneration) state = loaded;
  }

  Future<GamePeriod?> startDay() async {
    final current = state;
    if (_startingDay ||
        current is! HomeReady ||
        current.period != null ||
        current.allDaysCompleted) {
      return null;
    }
    _startingDay = true;
    state = current.copyWith(startingDay: true, startFailed: false);
    Object? mutationError;
    try {
      await ref
          .read(periodServiceProvider)
          .startNextPeriod(profileId: current.profile.id!);
    } catch (error) {
      mutationError = error;
    }

    final refreshed = await _readSnapshot();
    _startingDay = false;
    if (refreshed case HomeReady(:final period)) {
      if (period != null && period.status == GamePeriodStatus.planning) {
        state = refreshed;
        return period;
      }
      state = refreshed.copyWith(startFailed: mutationError != null);
      return null;
    }
    state = refreshed;
    return null;
  }

  Future<bool> finishDay() async {
    final current = state;
    final period = current is HomeReady ? current.period : null;
    if (_finishingDay ||
        current is! HomeReady ||
        period?.id == null ||
        period!.status != GamePeriodStatus.readyToFinish) {
      return false;
    }
    _finishingDay = true;
    state = current.copyWith(finishingDay: true, finishFailed: false);
    try {
      await ref
          .read(periodServiceProvider)
          .completePeriod(profileId: current.profile.id!, periodId: period.id!);
    } catch (_) {
      _finishingDay = false;
      final refreshed = await _readSnapshot();
      if (refreshed is HomeReady &&
          refreshed.completedDays > current.completedDays) {
        state = refreshed;
        return true;
      }
      state = current.copyWith(finishingDay: false, finishFailed: true);
      return false;
    }
    _finishingDay = false;
    state = await _readSnapshot();
    return true;
  }

  Future<HomeViewState> _readSnapshot() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return const HomeFailure();
    try {
      final values = await Future.wait<Object?>([
        ref.read(profileRepositoryProvider).findById(profileId),
        ref.read(gameRepositoryProvider).getPet(profileId),
        ref.read(gameRepositoryProvider).getGameState(profileId),
        ref.read(gameRepositoryProvider).getPeriods(profileId),
        ref.read(contentRepositoryProvider).loadPeriods(),
      ]);
      final profile = values[0] as Profile?;
      final pet = values[1] as Pet?;
      final gameState = values[2] as GameState?;
      final periods = values[3] as List<GamePeriod>;
      final definitions = values[4] as List<PeriodDefinition>;

      if (profile == null || profile.profileType != ProfileType.normal) {
        return const HomeFailure();
      }
      if (pet == null) return const HomeNeedsBootstrap();
      if (gameState == null) return const HomeFailure();

      final unfinished = periods
          .where((period) => period.status != GamePeriodStatus.completed)
          .toList(growable: false);
      if (unfinished.length > 1) return const HomeFailure();
      final period = unfinished.isEmpty ? null : unfinished.single;
      PeriodDefinition? definition;
      if (period != null) {
        final matches = definitions
            .where(
              (candidate) =>
                  candidate.id == period.definitionId &&
                  candidate.number == period.periodNumber,
            )
            .toList(growable: false);
        if (matches.length != 1) return const HomeFailure();
        definition = matches.single;
      }
      return HomeReady(
        profile: profile,
        pet: pet,
        gameState: gameState,
        period: period,
        definition: definition,
        completedDays: periods
            .where((item) => item.status == GamePeriodStatus.completed)
            .length,
        allDaysCompleted:
            definitions.isNotEmpty &&
            periods.length == definitions.length &&
            periods.every((item) => item.status == GamePeriodStatus.completed),
      );
    } catch (_) {
      return const HomeFailure();
    }
  }
}
