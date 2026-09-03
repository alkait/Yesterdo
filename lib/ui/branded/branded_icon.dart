import 'package:flutter/material.dart';

import 'brand.dart';

enum BrandedIconSize {
  small(15),
  medium(22),
  large(28);

  const BrandedIconSize(this.points);
  final double points;
}

/// The only way to put an icon on screen.
class BrandedIcon extends StatelessWidget {
  const BrandedIcon(
    this.icon, {
    super.key,
    this.size = BrandedIconSize.medium,
    this.tone = BrandedTone.muted,
  });

  final IconData icon;
  final BrandedIconSize size;
  final BrandedTone tone;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size.points,
    color: tone.resolve(Theme.of(context).colorScheme),
  );
}
