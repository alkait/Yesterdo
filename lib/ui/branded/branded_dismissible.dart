import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';

/// Swipe left to delete, with the one delete affordance this app draws.
class BrandedDismissible extends StatelessWidget {
  const BrandedDismissible({
    super.key,
    required this.dismissKey,
    required this.onDismissed,
    required this.child,
  });

  final Key dismissKey;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: dismissKey,
    direction: DismissDirection.endToStart,
    onDismissed: (_) => onDismissed(),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Brand.gutter),
      child: const BrandedIcon(
        Icons.delete_outline_rounded,
        tone: BrandedTone.danger,
      ),
    ),
    child: child,
  );
}
