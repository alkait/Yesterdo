import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'brand.dart';

/// A preview of one look: its surface, its hairline, and its accent in the
/// middle. Drawn at the brightness the screen is currently in, so the swatch
/// shows what picking it would actually do.
class BrandedThemeSwatch extends StatelessWidget {
  const BrandedThemeSwatch(this.choice, {super.key});

  final AppThemeChoice choice;

  @override
  Widget build(BuildContext context) {
    final scheme = AppTheme.schemeFor(choice, Theme.of(context).brightness);
    return Container(
      width: Brand.daySize,
      height: Brand.daySize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
        border: Border.all(
          color: scheme.outlineVariant,
          width: Brand.borderWidth,
        ),
      ),
      child: Container(
        width: Brand.checkSize,
        height: Brand.checkSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary,
        ),
      ),
    );
  }
}
