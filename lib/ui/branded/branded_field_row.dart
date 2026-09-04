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
    this.detail,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// Small print under the value. Nothing is drawn for null or empty.
  final String? detail;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: [label, value, ?detail].where((s) => s.isNotEmpty).join(', '),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Brand.rowMinHeight),
        padding: const EdgeInsets.symmetric(vertical: Brand.rowPadding),
        child: Row(
          children: [
            BrandedText(label, tone: BrandedTone.muted),
            const SizedBox(width: Brand.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandedText(value, maxLines: 1),
                  if (detail case final detail? when detail.isNotEmpty)
                    BrandedText(
                      detail,
                      role: BrandedTextRole.caption,
                      tone: BrandedTone.muted,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
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
