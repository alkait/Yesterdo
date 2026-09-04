import 'package:flutter/material.dart';

/// Makes a whole row liftable: press and hold, and it comes up under the
/// finger to be dragged into a new place. A quick sideways swipe or a double
/// tap never gets that far, so the row's other gestures are left alone.
class BrandedDragLift extends StatelessWidget {
  const BrandedDragLift({super.key, required this.index, required this.child});

  /// Position in the reorderable list this row sits at.
  final int index;

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    hint: 'Press and hold to reorder',
    child: ReorderableDelayedDragStartListener(index: index, child: child),
  );
}
