import 'package:flutter/material.dart';

import 'brand.dart';

/// A tappable list row. Sets the tap target height, the gutter, and the
/// surface behind it so a swipe reveals what is underneath.
class BrandedRow extends StatelessWidget {
  const BrandedRow({
    super.key,
    this.leading,
    required this.child,
    this.onTap,
  });

  final Widget? leading;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: Brand.rowMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: Brand.gutter,
        vertical: Brand.rowPadding,
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Brand.gap)],
          Expanded(child: child),
        ],
      ),
    ),
  );
}
