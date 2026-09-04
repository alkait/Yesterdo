import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_divider.dart';

/// The bottom chrome: a hairline on top, brand surface behind, and safe-area
/// padding so it clears the home indicator.
class BrandedBottomBar extends StatelessWidget {
  const BrandedBottomBar({
    super.key,
    required this.child,
    this.onTap,
    this.trailing,
  });

  final Widget child;

  /// When set, everything but [trailing] is one tap target.
  final VoidCallback? onTap;

  /// Sits at the right end, outside the bar's own tap target, so it can carry
  /// a button of its own.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      constraints: const BoxConstraints(minHeight: Brand.tapTarget),
      padding: const EdgeInsets.only(left: Brand.gutter),
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );

    if (onTap != null) {
      content = Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BrandedDivider.sideOf(context)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
          child: Row(
            children: [
              Expanded(child: content),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
