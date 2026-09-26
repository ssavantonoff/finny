import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Kept as the public widget name so existing Shop routes and tests can find the
// sheet. Opening it is now the only confirmation step.
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
  bool _closing = false;
  late final int? _openedPeriodId;
  late final int _openedPrice;
  late final bool _openedStatusInvalid;

  @override
  void initState() {
    super.initState();
    final opened = ref.read(shopControllerProvider);
    _openedPeriodId = opened.period?.id;
    _openedPrice = opened.effectivePriceFor(widget.item);
    _openedStatusInvalid =
        !opened.freePlay &&
        opened.period?.status != GamePeriodStatus.active &&
        opened.period?.status != GamePeriodStatus.readyToFinish;
    ref.listenManual(shopControllerProvider, (_, next) {
      if (_closing || !mounted) return;
      if (next.profileId != widget.profileId ||
          (next.load == ShopLoad.ready &&
              !sameShopItem(next.itemById(widget.item.id), widget.item)) ||
          next.result?.kind == ShopResultKind.contentChanged) {
        _close();
        return;
      }
      if (next.result?.kind == ShopResultKind.success) {
        _close();
        return;
      }
      if (next.load != ShopLoad.ready || next.purchasing) return;
      final invalidStatus =
          !next.freePlay &&
          next.period?.status != GamePeriodStatus.active &&
          next.period?.status != GamePeriodStatus.readyToFinish;
      if (next.period?.id != _openedPeriodId ||
          invalidStatus != _openedStatusInvalid ||
          next.effectivePriceFor(widget.item) != _openedPrice) {
        _close();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Магазин обновился. Открой товар снова.'),
          ),
        );
      }
    });
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopControllerProvider);
    final item = widget.item;
    final changed =
        state.profileId != widget.profileId ||
        (state.load == ShopLoad.ready &&
            !sameShopItem(state.itemById(item.id), item)) ||
        state.result?.kind == ShopResultKind.contentChanged;
    if (changed) _close();
    final stale =
        state.load == ShopLoad.ready &&
        (state.period?.id != _openedPeriodId ||
            state.effectivePriceFor(item) != _openedPrice);
    final allowed = !changed && !stale && state.canBuy(item);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9F7FF), Color(0xFFE9E7FF)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCC5FF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.primaryDark,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .8),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
                if (!changed) ...[
                  SizedBox(height: 166, child: ShopItemArt(item: item)),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A2368),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shopCategory(item),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 180,
                    child: ShopPriceLabel(
                      item: item,
                      state: state,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    shopItemDescription(item),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7778A5),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Купить «${item.name}» за $_openedPrice монет?',
                          key: const Key('shop-confirmation'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1A2368),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (state.purchasing ||
                            (state.result != null &&
                                state.result!.kind != ShopResultKind.success))
                          ShopPurchaseNotice(state: state),
                        if (state.unavailableReason(item) case final reason?)
                          ShopNotice(reason),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const Key('shop-buy'),
                            onPressed: !allowed
                                ? null
                                : () {
                                    final latest = ref.read(
                                      shopControllerProvider,
                                    );
                                    if (latest.profileId != widget.profileId ||
                                        latest.period?.id != _openedPeriodId ||
                                        latest.effectivePriceFor(item) !=
                                            _openedPrice ||
                                        !latest.canBuy(item)) {
                                      return;
                                    }
                                    unawaited(
                                      ref
                                          .read(shopControllerProvider.notifier)
                                          .buy(
                                            item.id,
                                            profileId: widget.profileId!,
                                            periodId: _openedPeriodId,
                                          ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: state.purchasing
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Купить за $_openedPrice'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          key: const Key('shop-cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Отмена'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
