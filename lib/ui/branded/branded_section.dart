import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_divider.dart';
import 'branded_text.dart';

/// A titled group of rows on a settings-like screen: a muted caption over a
/// recessed, rounded panel, with a hairline between one row and the next.
/// The panel is what sets one group apart from another.
class BrandedSection extends StatelessWidget {
  const BrandedSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;

  /// Drawn in order, a divider between each pair.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: Brand.sectionTitleInset,
            bottom: Brand.sectionTitleGap,
          ),
          child: BrandedText(
            title,
            role: BrandedTextRole.caption,
            tone: BrandedTone.muted,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Brand.cardRadius),
            border: Border.all(
              color: scheme.outlineVariant,
              width: Brand.borderWidth,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Brand.cardPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const BrandedDivider(),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
