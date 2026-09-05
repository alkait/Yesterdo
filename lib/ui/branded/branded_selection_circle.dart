import 'package:flutter/material.dart';

import 'brand.dart';

/// The circle this app uses to say "this one". Filled when selected, an
/// outline when it is merely worth noting, invisible otherwise. Shared by the
/// checkbox and the calendar so both can never drift apart.
class BrandedSelectionCircle extends StatelessWidget {
  const BrandedSelectionCircle({
    super.key,
    required this.selected,
    this.outlined = false,
    this.size = Brand.checkSize,
    this.bold = false,
    this.child,
  });

  final bool selected;
  final bool outlined;
  final double size;

  /// A heavier, darker outline, for a circle that has to be found and
  /// tapped rather than merely noticed.
  final bool bold;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Brand.quick,
      curve: Brand.curve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.transparent,
        border: selected || outlined
            ? Border.all(
                color: selected
                    ? scheme.primary
                    : bold
                    ? scheme.onSurfaceVariant
                    : scheme.outlineVariant,
                width: bold ? Brand.checkBoxBorder : 1.5,
              )
            : null,
      ),
      child: child,
    );
  }
}
