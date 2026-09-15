import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class AdultScreen extends StatelessWidget {
  const AdultScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Для взрослых',
    description:
        'Раздел намеренно оставлен без полной реализации на foundation-этапе.',
    currentPath: '/adult',
  );
}
