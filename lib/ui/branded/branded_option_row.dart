import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_text.dart';

/// One choice in a list of them. Ticked when it is the one in force.
class BrandedOptionRow extends StatelessWidget {
  const BrandedOptionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.tone = BrandedTone.primary,
  });

  final String label;
  final VoidCallback onTap;

  /// Shown ahead of the label, in the row's own tone.
  final IconData? icon;

  final bool selected;
  final BrandedTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Brand.rowMinHeight),
        padding: const EdgeInsets.symmetric(vertical: Brand.rowPadding),
        child: Row(
          children: [
            if (icon != null) ...[
              BrandedIcon(icon!, size: BrandedIconSize.medium, tone: tone),
              const SizedBox(width: Brand.gap),
            ],
            Expanded(child: BrandedText(label, tone: tone, maxLines: 1)),
            if (selected)
              const BrandedIcon(
                Icons.check_rounded,
                size: BrandedIconSize.medium,
                tone: BrandedTone.primary,
              ),
          ],
        ),
      ),
    ),
  );
}
