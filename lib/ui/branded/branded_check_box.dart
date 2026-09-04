import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_selection_circle.dart';

/// The tick on a checklist item: the app's selection circle with a check in
/// it when ticked. Tappable on its own, in the editor and the read view.
class BrandedCheckBox extends StatelessWidget {
  const BrandedCheckBox({super.key, required this.checked, this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    button: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: BrandedSelectionCircle(
        selected: checked,
        outlined: !checked,
        size: Brand.checkSize,
        child: checked
            ? const BrandedIcon(
                Icons.check_rounded,
                size: BrandedIconSize.small,
                tone: BrandedTone.inverted,
              )
            : null,
      ),
    ),
  );
}
