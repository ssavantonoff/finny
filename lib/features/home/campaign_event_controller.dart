import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/story_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CampaignEventKind { day3Bowl, day4Promotion }

class CampaignEventAttempt {
  const CampaignEventAttempt({
    required this.profileId,
    required this.periodId,
    required this.actionId,
    required this.operationId,
    required this.purchase,
    this.useSavings = false,
  });

  final int profileId;
  final int periodId;
  final String actionId;
  final String operationId;
  final bool purchase;
  final bool useSavings;
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
    this.storyEvent,
    this.mutating = false,
    this.message,
    this.pending,
  });

  final CampaignEventKind kind;
  final int profileId;
  final GamePeriod period;
  final StoryEventSnapshot? storyEvent;
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
    storyEvent: storyEvent,
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
      if (period == null ||
          (period.status != GamePeriodStatus.active &&
              period.status != GamePeriodStatus.readyToFinish)) {
        state = const CampaignEventIdle();
        return;
      }
      StoryEventSnapshot? bowl;
      if (period.periodNumber >= 3 && period.periodNumber <= 5) {
        bowl = await ref
            .read(storyEventServiceProvider)
            .armOrLoadDay3Bowl(profileId: profileId);
      }
      if (generation != _generation ||
          ref.read(activeProfileIdProvider) != profileId) {
        return;
      }
      final kind =
          bowl != null && bowl.status == StoryEventStatus.armed && bowl.isDue
          ? CampaignEventKind.day3Bowl
          : switch (period.periodNumber) {
              4
                  when period.resolvedCheckpoints.contains('financial_task') &&
                      !period.resolvedCheckpoints.contains(
                        'discount_decision',
                      ) =>
                CampaignEventKind.day4Promotion,
              _ => null,
            };
      state = kind == null
          ? const CampaignEventIdle()
          : CampaignEventReady(
              kind: kind,
              profileId: profileId,
              period: period,
              storyEvent: bowl,
            );
    } catch (_) {
      if (generation == _generation) state = const CampaignEventFailure();
    }
  }

  Future<bool> prepareBowlPurchase() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return false;
    final period = await ref
        .read(gameRepositoryProvider)
        .getCurrentPeriod(profileId);
    if (period == null ||
        period.id == null ||
        period.periodNumber < 3 ||
        period.periodNumber > 5 ||
        (period.status != GamePeriodStatus.active &&
            period.status != GamePeriodStatus.readyToFinish)) {
      return false;
    }
    final bowl = await ref
        .read(storyEventServiceProvider)
        .armOrLoadDay3Bowl(profileId: profileId);
    if (bowl == null || bowl.isPurchased || !bowl.isOutstanding) return false;
    state = CampaignEventReady(
      kind: CampaignEventKind.day3Bowl,
      profileId: profileId,
      period: period,
      storyEvent: bowl,
    );
    return true;
  }

  Future<bool> purchaseBowl() => _perform(
    actionId: 'day3_bowl_replacement',
    purchase: true,
    useSavings: false,
  );

  Future<bool> purchaseBowlFromSavings() => _perform(
    actionId: 'day3_bowl_replacement_savings',
    purchase: true,
    useSavings: true,
  );

  Future<bool> postponeBowl() => _perform(
    actionId: 'day3_bowl_replacement_postpone',
    purchase: false,
    useSavings: false,
  );

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
    bool useSavings = false,
  }) async {
    final current = state;
    if (_mutating || current is! CampaignEventReady) return false;
    final pending = current.pending;
    final attempt =
        pending != null &&
            pending.actionId == actionId &&
            pending.purchase == purchase &&
            pending.useSavings == useSavings
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
            useSavings: useSavings,
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
      if (current.kind == CampaignEventKind.day3Bowl) {
        final storyService = ref.read(storyEventServiceProvider);
        if (attempt.purchase) {
          await storyService.purchaseDay3Bowl(
            profileId: attempt.profileId,
            currentPeriodId: attempt.periodId,
            operationId: attempt.operationId,
            useSavings: attempt.useSavings,
          );
        } else {
          await storyService.postponeDay3Bowl(
            profileId: attempt.profileId,
            currentPeriodId: attempt.periodId,
            operationId: attempt.operationId,
          );
        }
      } else if (attempt.purchase) {
        await ref
            .read(specialPurchaseServiceProvider)
            .buyPromotion(
              profileId: attempt.profileId,
              periodId: attempt.periodId,
              promotionId: attempt.actionId,
              operationId: attempt.operationId,
            );
      } else {
        await ref
            .read(specialPurchaseServiceProvider)
            .skipPromotion(
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

    GamePeriod? refreshed;
    try {
      refreshed = await ref
          .read(gameRepositoryProvider)
          .getPeriodById(attempt.profileId, attempt.periodId);
    } catch (_) {
      state = current.copyWith(
        mutating: false,
        pending: attempt,
        message: 'Не удалось подтвердить результат. Проверить ещё раз.',
      );
      return false;
    }
    StoryEventSnapshot? bowl;
    if (current.kind == CampaignEventKind.day3Bowl) {
      try {
        bowl = await ref
            .read(storyEventServiceProvider)
            .loadDay3Bowl(profileId: attempt.profileId);
      } catch (_) {
        // Keep the dialog and operation identity available for retry.
      }
    }
    final bowlDecisionPersisted =
        bowl != null &&
        bowl.decisionOperationId == attempt.operationId &&
        (attempt.purchase
            ? bowl.status == StoryEventStatus.purchased &&
                  bowl.decisionKind ==
                      (attempt.useSavings
                          ? 'purchase_savings'
                          : 'purchase_wallet')
            : bowl.status == StoryEventStatus.postponed &&
                  bowl.decisionKind == 'postpone');
    if (current.kind == CampaignEventKind.day3Bowl && bowlDecisionPersisted) {
      state = current
          .copyWith(
            mutating: false,
            clearPending: true,
            message: attempt.purchase
                ? 'План остался прежним, а расходы изменились. Иногда важные траты '
                      'появляются неожиданно.'
                : 'Нужная покупка отложена. Пока Финни будет пользоваться временной миской.',
          )
          .copyWithStoryEvent(bowl);
      return true;
    }
    if (current.kind != CampaignEventKind.day3Bowl &&
        refreshed?.resolvedCheckpoints.contains('discount_decision') == true) {
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
    if (error is StoryEventInsufficientFundsException) {
      final message =
          error.walletBalance < error.price &&
              error.walletBalance + error.savedAmount >= error.price
          ? 'Не хватает ${error.deficit} монет. Можно взять их из копилки.'
          : 'В кошельке и копилке пока не хватает монет для этой покупки.';
      state = current
          .copyWith(mutating: false, pending: attempt, message: message)
          .copyWithStoryEvent(bowl ?? current.storyEvent);
      return false;
    }
    state = current
        .copyWith(
          mutating: false,
          pending: attempt,
          message: 'Не удалось подтвердить результат. Проверить ещё раз.',
        )
        .copyWithStoryEvent(bowl ?? current.storyEvent);
    return false;
  }
}

extension on CampaignEventReady {
  CampaignEventReady copyWithStoryEvent(StoryEventSnapshot? storyEvent) =>
      CampaignEventReady(
        kind: kind,
        profileId: profileId,
        period: period,
        storyEvent: storyEvent,
        mutating: mutating,
        message: message,
        pending: pending,
      );
}
