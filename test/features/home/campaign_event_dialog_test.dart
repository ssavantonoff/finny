import 'package:finny/core/theme/app_theme.dart';
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
  int purchases = 0;
  int postpones = 0;

  @override
  CampaignEventState build() => initialState;

  void emit(CampaignEventState next) => state = next;

  @override
  Future<bool> purchaseBowl() async {
    purchases++;
    emit(
      _readyBowl(
        wallet: 80,
        status: StoryEventStatus.purchased,
        message: 'План остался прежним, а расходы изменились.',
      ),
    );
    return true;
  }

  @override
  Future<bool> postponeBowl() async {
    postpones++;
    emit(
      _readyBowl(
        status: StoryEventStatus.postponed,
        message: 'Нужная покупка отложена.',
      ),
    );
    return true;
  }
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

StoryEventSnapshot _bowl({
  int wallet = 200,
  int saved = 0,
  StoryEventStatus status = StoryEventStatus.armed,
}) => StoryEventSnapshot(
  profileId: 1,
  storyId: 'day3_bowl_replacement',
  originPeriodId: 3,
  originPeriodNumber: 3,
  threshold: 1,
  qualifyingInteractionCount: 1,
  status: status,
  currentPeriodId: 3,
  currentPeriodNumber: 3,
  walletBalance: wallet,
  savedAmount: saved,
  price: 120,
  savingsUsed: 0,
  wasPostponed: false,
);

CampaignEventReady _readyBowl({
  int wallet = 200,
  int saved = 0,
  String? message,
  CampaignEventAttempt? pending,
  StoryEventStatus status = StoryEventStatus.armed,
}) => CampaignEventReady(
  kind: CampaignEventKind.day3Bowl,
  profileId: 1,
  period: _period(3),
  storyEvent: _bowl(wallet: wallet, saved: saved, status: status),
  message: message,
  pending: pending,
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
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('bowl result shows resolved state at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpDialog(
        tester,
        initialState: _readyBowl(
          wallet: 80,
          status: StoryEventStatus.purchased,
          message: 'Покупка сохранена.',
        ),
      );
      expect(find.text('Новая миска куплена'), findsOneWidget);
      expect(find.text('Баланс сейчас: 80 монет'), findsOneWidget);
      expect(find.textContaining('План остался прежним'), findsOneWidget);

      expect(find.text('Покупка сохранена.'), findsNothing);
      expect(find.byKey(const Key('campaign-bowl-understood')), findsOneWidget);
      final understood = tester.widget<FilledButton>(
        find.byKey(const Key('campaign-bowl-understood')),
      );
      expect(understood.style!.backgroundColor!.resolve({}), AppColors.primary);
      expect(understood.style!.shape!.resolve({}), isA<StadiumBorder>());
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'bowl decision actions use Finny styles and handlers at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await _pumpDialog(tester, initialState: _readyBowl());
        expect(find.byType(Chip), findsNothing);
        final need = tester.widget<Text>(find.text('Нужно'));
        expect(need.style!.color, AppColors.need);
        final buy = tester.widget<FilledButton>(
          find.byKey(const Key('campaign-buy-bowl')),
        );
        final postpone = tester.widget<TextButton>(
          find.byKey(const Key('campaign-bowl-postpone')),
        );
        expect(buy.style!.backgroundColor!.resolve({}), AppColors.primary);
        expect(buy.style!.foregroundColor!.resolve({}), Colors.white);
        expect(buy.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(
          postpone.style!.foregroundColor!.resolve({}),
          AppColors.primaryDark,
        );
        expect(postpone.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('campaign-buy-bowl')));
        await tester.pump();
        expect(harness.controller.purchases, 1);
        expect(find.text('Новая миска куплена'), findsOneWidget);
        expect(find.text('Баланс сейчас: 80 монет'), findsOneWidget);
        expect(find.textContaining('План остался прежним'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        final postponed = await _pumpDialog(tester, initialState: _readyBowl());
        await tester.tap(find.byKey(const Key('campaign-bowl-postpone')));
        await tester.pump();
        expect(postponed.controller.postpones, 1);
        expect(find.text('Новая миска'), findsOneWidget);
      },
    );
  }

  testWidgets('bowl savings confirmation and retry keep Finny styling', (
    tester,
  ) async {
    await _pumpDialog(tester, initialState: _readyBowl(wallet: 50, saved: 100));
    final savings = tester.widget<FilledButton>(
      find.byKey(const Key('campaign-bowl-savings')),
    );
    expect(savings.style!.backgroundColor!.resolve({}), AppColors.primary);
    await tester.tap(find.byKey(const Key('campaign-bowl-savings')));
    await tester.pumpAndSettle();
    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Отмена'),
    );
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Использовать'),
    );
    expect(cancel.style!.foregroundColor!.resolve({}), AppColors.primaryDark);
    expect(confirm.style!.backgroundColor!.resolve({}), AppColors.primary);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());

    final harness = await _pumpDialog(
      tester,
      initialState: _readyBowl(
        wallet: 50,
        message: 'Проверить ещё раз.',
        pending: const CampaignEventAttempt(
          profileId: 1,
          periodId: 3,
          actionId: 'day3_bowl_replacement',
          operationId: 'retry-test',
          purchase: true,
        ),
      ),
    );
    expect(find.text('Проверить ещё раз.'), findsOneWidget);
    expect(find.byKey(const Key('campaign-retry')), findsOneWidget);
    expect(harness.controller.purchases, 0);
  });

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
      expect(find.text('Сейчас — 50 монет'), findsOneWidget);
      expect(find.text('Проверить ещё раз.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      harness.controller.emit(const CampaignEventFailure());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Сейчас — 50 монет'), findsOneWidget);
    },
  );
}
