import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_selection_circle.dart';

/// The only checkbox in the app.
class BrandedCheckbox extends StatelessWidget {
  const BrandedCheckbox({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => Padding(
    // Nudged down so it sits on the first line of a wrapping label.
    padding: const EdgeInsets.only(top: 2),
    child: BrandedSelectionCircle(
      selected: checked,
      outlined: !checked,
      child: checked
          ? const BrandedIcon(
              Icons.check_rounded,
              size: BrandedIconSize.small,
              tone: BrandedTone.inverted,
            )
          : null,
    ),
  );
}
