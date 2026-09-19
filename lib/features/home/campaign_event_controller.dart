import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CampaignEventKind { day3Bowl, day4Promotion }

class CampaignEventAttempt {
  const CampaignEventAttempt({
    required this.profileId,
    required this.periodId,
    required this.actionId,
    required this.operationId,
    required this.purchase,
  });

  final int profileId;
  final int periodId;
  final String actionId;
  final String operationId;
  final bool purchase;
}

sealed class CampaignEventState {
  const CampaignEventState();
}

class CampaignEventIdle extends CampaignEventState {
  const CampaignEventIdle();
}

class CampaignEventReady extends CampaignEventState {
  const CampaignEventReady({
    required this.kind,
    required this.profileId,
    required this.period,
    this.mutating = false,
    this.message,
    this.pending,
  });

  final CampaignEventKind kind;
  final int profileId;
  final GamePeriod period;
  final bool mutating;
  final String? message;
  final CampaignEventAttempt? pending;

  CampaignEventReady copyWith({
    bool? mutating,
    String? message,
    bool clearMessage = false,
    CampaignEventAttempt? pending,
    bool clearPending = false,
  }) => CampaignEventReady(
    kind: kind,
    profileId: profileId,
    period: period,
    mutating: mutating ?? this.mutating,
    message: clearMessage ? null : message ?? this.message,
    pending: clearPending ? null : pending ?? this.pending,
  );
}

class CampaignEventFailure extends CampaignEventState {
  const CampaignEventFailure();
}

typedef CampaignOperationIdFactory = String Function(
  int profileId,
  int periodId,
  String actionId,
);

final campaignEventControllerProvider =
    NotifierProvider<CampaignEventController, CampaignEventState>(
      CampaignEventController.new,
    );

class CampaignEventController extends Notifier<CampaignEventState> {
  CampaignEventController({this.operationIdFactory});

  final CampaignOperationIdFactory? operationIdFactory;
  int _generation = 0;
  int _counter = 0;
  bool _mutating = false;

  @override
  CampaignEventState build() {
    ref.listen<int?>(activeProfileIdProvider, (_, _) => unawaited(load()));
    return const CampaignEventIdle();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) {
      state = const CampaignEventIdle();
      return;
    }
    try {
      final period = await ref
          .read(gameRepositoryProvider)
          .getCurrentPeriod(profileId);
      if (generation != _generation ||
          ref.read(activeProfileIdProvider) != profileId) {
        return;
      }
      if (period == null || period.status != GamePeriodStatus.active) {
        state = const CampaignEventIdle();
        return;
      }
      final kind = switch (period.periodNumber) {
        3 when !period.resolvedCheckpoints.contains('changed_circumstance') =>
          CampaignEventKind.day3Bowl,
        4
            when period.resolvedCheckpoints.contains('financial_task') &&
                !period.resolvedCheckpoints.contains('discount_decision') =>
          CampaignEventKind.day4Promotion,
        _ => null,
      };
      state = kind == null
          ? const CampaignEventIdle()
          : CampaignEventReady(
              kind: kind,
              profileId: profileId,
              period: period,
            );
    } catch (_) {
      if (generation == _generation) state = const CampaignEventFailure();
    }
  }

  Future<bool> purchaseBowl() =>
      _perform(actionId: 'day3_bowl_replacement', purchase: true);

  Future<bool> buyPromotion() =>
      _perform(actionId: 'day4_treat_discount', purchase: true);

  Future<bool> skipPromotion() =>
      _perform(actionId: 'day4_treat_discount', purchase: false);

  Future<bool> retry() async {
    final current = state;
    if (current is! CampaignEventReady || current.pending == null) return false;
    return _performAttempt(current.pending!);
  }

  Future<bool> _perform({
    required String actionId,
    required bool purchase,
  }) async {
    final current = state;
    if (_mutating || current is! CampaignEventReady) return false;
    final pending = current.pending;
    final attempt =
        pending != null &&
            pending.actionId == actionId &&
            pending.purchase == purchase
        ? pending
        : CampaignEventAttempt(
            profileId: current.profileId,
            periodId: current.period.id!,
            actionId: actionId,
            operationId:
                operationIdFactory?.call(
                  current.profileId,
                  current.period.id!,
                  actionId,
                ) ??
                'campaign:${current.profileId}:${current.period.id}:$actionId:${purchase ? 'buy' : 'skip'}:${DateTime.now().microsecondsSinceEpoch}:${++_counter}',
            purchase: purchase,
          );
    return _performAttempt(attempt);
  }

  Future<bool> _performAttempt(CampaignEventAttempt attempt) async {
    final current = state;
    if (_mutating || current is! CampaignEventReady) return false;
    _mutating = true;
    state = current.copyWith(
      mutating: true,
      pending: attempt,
      clearMessage: true,
    );
    Object? error;
    try {
      final service = ref.read(specialPurchaseServiceProvider);
      if (current.kind == CampaignEventKind.day3Bowl) {
        await service.purchaseStory(
          profileId: attempt.profileId,
          periodId: attempt.periodId,
          storyPurchaseId: attempt.actionId,
          operationId: attempt.operationId,
        );
      } else if (attempt.purchase) {
        await service.buyPromotion(
          profileId: attempt.profileId,
          periodId: attempt.periodId,
          promotionId: attempt.actionId,
          operationId: attempt.operationId,
        );
      } else {
        await service.skipPromotion(
          profileId: attempt.profileId,
          periodId: attempt.periodId,
          promotionId: attempt.actionId,
          operationId: attempt.operationId,
        );
      }
    } catch (caught) {
      error = caught;
    }
    _mutating = false;
    if (ref.read(activeProfileIdProvider) != attempt.profileId) return false;

    final refreshed = await ref
        .read(gameRepositoryProvider)
        .getPeriodById(attempt.profileId, attempt.periodId);
    final checkpoint = current.kind == CampaignEventKind.day3Bowl
        ? 'changed_circumstance'
        : 'discount_decision';
    if (refreshed?.resolvedCheckpoints.contains(checkpoint) == true) {
      state = const CampaignEventIdle();
      return true;
    }
    if (error is InsufficientFundsException) {
      state = current.copyWith(
        mutating: false,
        clearPending: true,
        message: 'Не хватает монет. Можно пропустить акцию.',
      );
      return false;
    }
    state = current.copyWith(
      mutating: false,
      pending: attempt,
      message: 'Не удалось подтвердить результат. Проверить ещё раз.',
    );
    return false;
  }
}
