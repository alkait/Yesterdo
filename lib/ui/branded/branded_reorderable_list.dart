import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

/// A list whose items can be dragged into a new order. Dragging is started by
/// holding a [BrandedDragLift], never by a plain press on the item.
class BrandedReorderableList extends StatelessWidget {
  const BrandedReorderableList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
    padding: const EdgeInsets.only(top: Brand.cardGap, bottom: 16),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    buildDefaultDragHandles: false,
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    onReorderItem: onReorder,
    // With no grip to see, the lift is felt instead.
    onReorderStart: (_) => HapticFeedback.selectionClick(),
    // The default lifts the item on a Material shadow. Flat design instead
    // nudges its scale so the card reads as picked up.
    proxyDecorator: (child, index, animation) => AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(scale: 1 + 0.03 * t, child: inner);
      },
      child: child,
    ),
  );
}
