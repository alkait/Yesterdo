import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

/// A list whose items can be dragged into a new order. Dragging is started by
/// holding a [BrandedDragLift], never by a plain press on the item. It
/// scrolls on its own and fills what it is given; on a page that scrolls
/// already, use [BrandedReorderableSliver] instead.
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
    proxyDecorator: brandedDragProxy,
  );
}

/// How a lifted item is drawn while it is dragged. The default lifts it on
/// a Material shadow; flat design instead nudges its scale so it reads as
/// picked up.
Widget brandedDragProxy(Widget child, int index, Animation<double> animation) =>
    AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(scale: 1 + 0.03 * t, child: inner);
      },
      child: child,
    );
