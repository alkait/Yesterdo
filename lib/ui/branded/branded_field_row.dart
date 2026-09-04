import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_text.dart';

/// A setting on a form: what it is on the left, what it says on the right, and
/// a chevron because tapping opens something.
class BrandedFieldRow extends StatelessWidget {
  const BrandedFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $value',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Brand.rowMinHeight),
        padding: const EdgeInsets.symmetric(vertical: Brand.rowPadding),
        child: Row(
          children: [
            BrandedText(label, tone: BrandedTone.muted),
            const Spacer(),
            BrandedText(value, maxLines: 1),
            const SizedBox(width: 4),
            const BrandedIcon(
              Icons.chevron_right_rounded,
              size: BrandedIconSize.medium,
            ),
          ],
        ),
      ),
    ),
  );
}
