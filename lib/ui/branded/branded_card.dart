import 'package:flutter/material.dart';

import 'brand.dart';

/// One item in a list, drawn as a bordered card so the eye separates it from
/// its neighbours without a rule between them.
class BrandedCard extends StatelessWidget {
  const BrandedCard({
    super.key,
    this.leading,
    required this.child,
    this.trailing,
    this.onTap,
    this.recessed = false,
  });

  final Widget? leading;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Settles the card into the background, for content that is done with.
  final bool recessed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Brand.gutter,
          vertical: Brand.cardGap / 2,
        ),
        constraints: const BoxConstraints(minHeight: Brand.rowMinHeight),
        decoration: BoxDecoration(
          color: recessed ? scheme.surfaceContainerHighest : scheme.surface,
          borderRadius: BorderRadius.circular(Brand.cardRadius),
          border: Border.all(
            color: scheme.outlineVariant,
            width: Brand.borderWidth,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Brand.cardPaddingH,
          vertical: Brand.cardPaddingV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: Brand.gap),
            ],
            Expanded(child: child),
            if (trailing != null) ...[
              const SizedBox(width: Brand.gap),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
