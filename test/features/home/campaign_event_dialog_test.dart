import 'package:finny/features/home/campaign_event_controller.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/story_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCampaignEventController extends CampaignEventController {
  _FakeCampaignEventController(this.initialState);

  final CampaignEventState initialState;

  @override
  CampaignEventState build() => initialState;

  void emit(CampaignEventState next) => state = next;
}

GamePeriod _period(int number) => GamePeriod(
  id: number,
  profileId: 1,
  definitionId: 'period_$number',
  periodNumber: number,
  startWalletBalance: 200,
  baseIncome: 500,
  extraIncome: 0,
  plannedNeed: 0,
  plannedWant: 0,
  plannedSavings: 0,
  plannedFree: 0,
  actualNeed: 0,
  actualWant: 0,
  actualSavings: 0,
  requiredCheckpoints: const ['financial_task'],
  resolvedCheckpoints: const ['financial_task'],
  growthPointsEarned: 0,
  status: GamePeriodStatus.active,
  createdAt: DateTime.utc(2026, 1, number),
);

StoryEventSnapshot _bowl({int wallet = 200}) => StoryEventSnapshot(
  profileId: 1,
  storyId: 'day3_bowl_replacement',
  originPeriodId: 3,
  originPeriodNumber: 3,
  threshold: 1,
  qualifyingInteractionCount: 1,
  status: StoryEventStatus.armed,
  currentPeriodId: 3,
  currentPeriodNumber: 3,
  walletBalance: wallet,
  savedAmount: 0,
  price: 120,
  savingsUsed: 0,
  wasPostponed: false,
);

CampaignEventReady _readyBowl({int wallet = 200, String? message}) =>
    CampaignEventReady(
      kind: CampaignEventKind.day3Bowl,
      profileId: 1,
      period: _period(3),
      storyEvent: _bowl(wallet: wallet),
      message: message,
    );

Future<({ProviderContainer container, _FakeCampaignEventController controller})>
_pumpDialog(
  WidgetTester tester, {
  required CampaignEventReady initialState,
}) async {
  final container = ProviderContainer(
    overrides: [
      campaignEventControllerProvider.overrideWith(
        () => _FakeCampaignEventController(initialState),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: CampaignEventDialog(
            initialState: initialState,
            walletBalance: initialState.storyEvent?.walletBalance ?? 200,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (
    container: container,
    controller: container.read(
      campaignEventControllerProvider.notifier,
    ) as _FakeCampaignEventController,
  );
}

void main() {
  testWidgets(
    'bowl dialog keeps the last Ready snapshot across transient state',
    (tester) async {
      final harness = await _pumpDialog(tester, initialState: _readyBowl());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ой! Миска Финни сломалась'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      harness.controller.emit(const CampaignEventIdle());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ой! Миска Финни сломалась'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      harness.controller.emit(
        _readyBowl(wallet: 50, message: 'Проверить ещё раз.'),
      );
      await tester.pump();
      expect(find.text('Баланс сейчас: 50 монет'), findsOneWidget);
      expect(find.text('Проверить ещё раз.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      harness.controller.emit(const CampaignEventFailure());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Баланс сейчас: 50 монет'), findsOneWidget);
    },
  );
}
