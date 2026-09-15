import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Магазин',
    description:
        'Товары будут загружаться из JSON и покупаться через PurchaseService.',
    currentPath: '/shop',
  );
}
