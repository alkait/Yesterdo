import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_text.dart';

/// A setting that is on or off: what it is on the left, a switch on the
/// right. The whole row takes the tap. Flat, like everything else: the
/// switch is a track and a thumb, no Material ripple.
class BrandedToggleRow extends StatelessWidget {
  const BrandedToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Small print under the label. Nothing is drawn for null or empty.
  final String? detail;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: Brand.rowMinHeight),
        padding: const EdgeInsets.symmetric(vertical: Brand.rowPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandedText(label, tone: BrandedTone.muted),
                  if (detail case final detail? when detail.isNotEmpty)
                    BrandedText(
                      detail,
                      role: BrandedTextRole.caption,
                      tone: BrandedTone.muted,
                    ),
                ],
              ),
            ),
            const SizedBox(width: Brand.gap),
            _Switch(on: value),
          ],
        ),
      ),
    ),
  );
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Brand.quick,
      curve: Brand.curve,
      width: Brand.switchWidth,
      height: Brand.switchHeight,
      padding: const EdgeInsets.all(Brand.switchInset),
      decoration: BoxDecoration(
        color: on ? scheme.primary : scheme.outlineVariant,
        borderRadius: BorderRadius.circular(Brand.switchHeight / 2),
      ),
      child: AnimatedAlign(
        duration: Brand.quick,
        curve: Brand.curve,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: Brand.switchHeight - Brand.switchInset * 2,
          height: Brand.switchHeight - Brand.switchInset * 2,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
