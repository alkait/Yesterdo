import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';

/// The grip that starts a reorder. Dragging begins here and nowhere else, so
/// a plain swipe across a card still means delete.
class BrandedDragHandle extends StatelessWidget {
  const BrandedDragHandle({super.key, required this.index});

  /// Position in the reorderable list this handle belongs to.
  final int index;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: Semantics(
      label: 'Drag to reorder',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: BrandedIcon(
          Icons.drag_indicator_rounded,
          tone: BrandedTone.muted,
        ),
      ),
    ),
  );
}
