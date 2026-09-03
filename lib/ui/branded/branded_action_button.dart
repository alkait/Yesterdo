import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_text.dart';

/// A big, flat action tile: icon over label, filled with the brand's raised
/// surface. Used wherever the app offers a short list of things to do.
class BrandedActionButton extends StatelessWidget {
  const BrandedActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = BrandedTone.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final BrandedTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: Brand.tileHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Brand.tileRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandedIcon(icon, size: BrandedIconSize.large, tone: tone),
            const SizedBox(height: 8),
            BrandedText(
              label,
              role: BrandedTextRole.label,
              tone: tone,
              align: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    ),
  );
}
