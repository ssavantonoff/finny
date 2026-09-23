import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopItemDetails extends ConsumerStatefulWidget {
  const ShopItemDetails({
    super.key,
    required this.item,
    required this.profileId,
  });
  final ShopItem item;
  final int? profileId;
  @override
  ConsumerState<ShopItemDetails> createState() => _ShopItemDetailsState();
}

class _ShopItemDetailsState extends ConsumerState<ShopItemDetails> {
  bool _confirming = false;
  bool _closing = false;
  int? _periodId;
  int? _confirmedPrice;

  @override
  void initState() {
    super.initState();
    ref.listenManual(shopControllerProvider, (_, next) {
      if (next.profileId != widget.profileId) return;
      if (next.result?.kind == ShopResultKind.success && !_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
        return;
      }
      if (!_confirming || _closing) return;
      if (next.load != ShopLoad.ready) return;
      final periodChanged = next.period?.id != _periodId;
      final statusInvalid =
          !periodChanged &&
          next.period != null &&
          next.period!.status != GamePeriodStatus.active &&
          next.period!.status != GamePeriodStatus.readyToFinish;
      if (!periodChanged && !statusInvalid) return;
      setState(() {
        _confirming = false;
        _periodId = null;
        _confirmedPrice = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Игровой период изменился. Подтверди покупку ещё раз.'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopControllerProvider);
    final controller = ref.read(shopControllerProvider.notifier);
    final item = widget.item;
    final changed =
        state.profileId != widget.profileId ||
        (state.load == ShopLoad.ready &&
            !sameShopItem(state.itemById(item.id), item)) ||
        state.result?.kind == ShopResultKind.contentChanged;
    if (changed && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    final allowed = !changed && state.canBuy(item);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            if (!changed) ...[
              Center(child: ShopItemIcon(item: item)),
              const SizedBox(height: AppSpacing.medium),
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              ShopPriceLabel(item: item, state: state, fontSize: 18),
              if (shopEffect(item) case final effect?) ...[
                const SizedBox(height: AppSpacing.medium),
                const Text('Ожидаемый эффект', style: TextStyle(fontSize: 16)),
                Text(effect, style: const TextStyle(fontSize: 18)),
              ],
              if (state.purchasing ||
                  (state.result != null &&
                      state.result!.kind != ShopResultKind.success))
                ShopPurchaseNotice(state: state),
              if (state.unavailableReason(item) case final reason?)
                ShopNotice(reason),
              const SizedBox(height: AppSpacing.large),
              if (_confirming && !state.purchasing) ...[
                Text(
                  'Купить «${item.name}» за ${_confirmedPrice ?? state.effectivePriceFor(item)} монет?',
                  key: const Key('shop-confirmation'),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.medium),
              ],
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const Key('shop-buy'),
                  onPressed: !allowed
                      ? null
                      : () {
                          final latest = ref.read(shopControllerProvider);
                          if (latest.profileId != widget.profileId ||
                              !latest.canBuy(item)) {
                            return;
                          }
                          if (!_confirming) {
                            setState(() {
                              _confirming = true;
                              _periodId = latest.period?.id;
                              _confirmedPrice = latest.effectivePriceFor(item);
                            });
                          } else {
                            if (_confirmedPrice !=
                                latest.effectivePriceFor(item)) {
                              setState(() {
                                _confirming = false;
                                _confirmedPrice = null;
                              });
                              return;
                            }
                            setState(() => _confirming = false);
                            unawaited(
                              controller.buy(
                                item.id,
                                profileId: widget.profileId!,
                                periodId: _periodId,
                              ),
                            );
                          }
                        },
                  child: state.purchasing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_confirming ? 'Купить' : 'К покупке'),
                ),
              ),
              if (_confirming)
                TextButton(
                  onPressed: () => setState(() => _confirming = false),
                  child: const Text('Отмена'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
