import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_divider.dart';

/// The bottom chrome: a hairline on top, brand surface behind, and safe-area
/// padding so it clears the home indicator.
class BrandedBottomBar extends StatelessWidget {
  const BrandedBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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
}
