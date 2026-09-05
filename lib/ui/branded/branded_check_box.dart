import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_selection_circle.dart';

/// The tick on a checklist item: the app's selection circle, drawn bold and
/// a little larger, with a check in it when ticked. Given [onTap] it sits
/// in a wide tap target, so a finger need not land on the circle itself;
/// without one, on a card, it is the bare circle.
class BrandedCheckBox extends StatelessWidget {
  const BrandedCheckBox({super.key, required this.checked, this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final circle = BrandedSelectionCircle(
      selected: checked,
      outlined: !checked,
      bold: true,
      size: Brand.checkBoxSize,
      child: checked
          ? const BrandedIcon(
              Icons.check_rounded,
              size: BrandedIconSize.small,
              tone: BrandedTone.inverted,
            )
          : null,
    );
    if (onTap == null) return Semantics(checked: checked, child: circle);
    return Semantics(
      checked: checked,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: Brand.tapTarget,
          height: Brand.checkBoxHitHeight,
          child: Center(child: circle),
        ),
      ),
    );
  }
}
