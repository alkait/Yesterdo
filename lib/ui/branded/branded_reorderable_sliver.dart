import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'branded_reorderable_list.dart';

/// A run of items that can be dragged into a new order, as a sliver on a
/// page that scrolls. Dragging is started by holding a [BrandedDragLift],
/// never by a plain press on the item.
///
/// A sliver, not a list of its own, so a drag towards the top or the
/// bottom of the screen scrolls the page the items are on, the way a
/// drag on the day scrolls the day.
class BrandedReorderableSliver extends StatelessWidget {
  const BrandedReorderableSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) => SliverReorderableList(
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    onReorderItem: onReorder,
    // With no grip to see, the lift is felt instead.
    onReorderStart: (_) => HapticFeedback.selectionClick(),
    proxyDecorator: brandedDragProxy,
  );
}
