import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_divider.dart';

/// The bottom chrome: a hairline on top, brand surface behind, and safe-area
/// padding so it clears the home indicator.
class BrandedBottomBar extends StatelessWidget {
  const BrandedBottomBar({super.key, required this.child, this.onTap});

  final Widget child;

  /// When set, the whole bar is one tap target.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BrandedDivider.sideOf(context)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 6, 10, 6),
          child: child,
        ),
      ),
    );

    if (onTap == null) return bar;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: bar,
      ),
    );
  }
}
