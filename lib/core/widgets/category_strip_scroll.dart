import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Allows desktop and emulator mouse dragging on a horizontal category strip.
class CategoryStripScroll extends StatelessWidget {
  const CategoryStripScroll({super.key, required this.child});

  final Widget child;

  static void revealSelected(BuildContext chipContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!chipContext.mounted) return;
      final scrollable = Scrollable.maybeOf(chipContext);
      final chip = chipContext.findRenderObject();
      if (scrollable == null || chip == null) return;
      unawaited(
        scrollable.position.ensureVisible(
          chip,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: child,
    );
  }
}
