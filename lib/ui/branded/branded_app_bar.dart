import 'package:flutter/material.dart';

import 'branded_divider.dart';

/// The top chrome: something either side, something in the middle, and a
/// hairline underneath. Flat, with no Material elevation. The sides are
/// given equal room, so the middle sits on the screen's centre line whatever
/// is or is not beside it.
class BrandedAppBar extends StatelessWidget {
  const BrandedAppBar({
    super.key,
    this.leading,
    this.trailing,
    required this.center,
    this.onTapCenter,
  });

  final Widget? leading;
  final Widget? trailing;
  final Widget center;
  final VoidCallback? onTapCenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: leading ?? const SizedBox.shrink(),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapCenter,
                child: center,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        const BrandedDivider(),
      ],
    );
  }
}
