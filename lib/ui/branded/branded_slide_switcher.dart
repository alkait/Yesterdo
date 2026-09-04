import 'package:flutter/material.dart';

import 'brand.dart';

/// Swaps one page for another by sliding: the old one out one side, the new
/// one in from the other. [direction] is 1 for a turn forwards, where the new
/// page comes from the right, and -1 for a turn back. Pages are told apart by
/// [pageKey]; the same key means no turn at all.
class BrandedSlideSwitcher extends StatelessWidget {
  const BrandedSlideSwitcher({
    super.key,
    required this.pageKey,
    required this.direction,
    required this.child,
  });

  final Object pageKey;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: Brand.turn,
      switchInCurve: Brand.curve,
      switchOutCurve: Brand.curve,
      transitionBuilder: (page, animation) {
        // The page on its way in is the one carrying the current key; the
        // other is on its way out, and its animation runs back down to zero.
        final incoming = page.key == ValueKey(pageKey);
        final from = Offset(
          incoming ? direction.toDouble() : -direction.toDouble(),
          0,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: from,
            end: Offset.zero,
          ).animate(animation),
          child: page,
        );
      },
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(pageKey), child: child),
    ),
  );
}
