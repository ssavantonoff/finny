import 'package:finny/app/providers.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/period_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class PeriodSummaryViewState {
  const PeriodSummaryViewState();
}

class PeriodSummaryLoading extends PeriodSummaryViewState {
  const PeriodSummaryLoading();
}

class PeriodSummaryFailure extends PeriodSummaryViewState {
  const PeriodSummaryFailure();
}

class PeriodSummaryReady extends PeriodSummaryViewState {
  const PeriodSummaryReady({required this.period, required this.summary});
  final GamePeriod period;
  final PeriodSummary summary;
}

final periodSummaryControllerProvider =
    NotifierProvider<PeriodSummaryController, PeriodSummaryViewState>(
      PeriodSummaryController.new,
    );

class PeriodSummaryController extends Notifier<PeriodSummaryViewState> {
  int _generation = 0;

  @override
  PeriodSummaryViewState build() => const PeriodSummaryLoading();

  Future<void> load() async {
    final generation = ++_generation;
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) {
      state = const PeriodSummaryFailure();
      return;
    }
    state = const PeriodSummaryLoading();
    try {
      final periods = await ref
          .read(gameRepositoryProvider)
          .getPeriods(profileId);
      final completed = periods
          .where((period) => period.status == GamePeriodStatus.completed)
          .toList(growable: false);
      if (completed.isEmpty) throw StateError('No completed period.');
      final period = completed.last;
      final summary = await ref
          .read(periodServiceProvider)
          .getSummary(profileId: profileId, periodId: period.id!);
      if (generation == _generation &&
          ref.read(activeProfileIdProvider) == profileId) {
        state = PeriodSummaryReady(period: period, summary: summary);
      }
    } catch (_) {
      if (generation == _generation &&
          ref.read(activeProfileIdProvider) == profileId) {
        state = const PeriodSummaryFailure();
      }
    }
  }
}
