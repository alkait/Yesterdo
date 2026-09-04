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
    this.leading,
    this.detail,
    this.selected = false,
    this.tone = BrandedTone.primary,
  }) : assert(icon == null || leading == null, 'pick an icon or a leading');

  final String label;
  final VoidCallback onTap;

  /// Shown ahead of the label, in the row's own tone.
  final IconData? icon;

  /// Shown ahead of the label instead of an icon, for something that is not
  /// one, such as a swatch.
  final Widget? leading;

  /// Small print under the label. Nothing is drawn for null or empty.
  final String? detail;

  final bool selected;
  final BrandedTone tone;

  @override
  Widget build(BuildContext context) {
    final ahead =
        leading ??
        (icon == null
            ? null
            : BrandedIcon(icon!, size: BrandedIconSize.medium, tone: tone));

    return Semantics(
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
              if (ahead != null) ...[ahead, const SizedBox(width: Brand.gap)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandedText(label, tone: tone, maxLines: 1),
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
}
