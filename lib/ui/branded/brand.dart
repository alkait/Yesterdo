import 'package:flutter/material.dart';

/// Every metric the interface is allowed to use. Change a number here and it
/// moves everywhere at once.
abstract final class Brand {
  // Spacing and size
  static const gutter = 20.0;
  static const gap = 14.0;
  static const rowMinHeight = 52.0;
  static const rowPadding = 12.0;
  static const cardRadius = 12.0;
  static const cardGap = 8.0;
  static const cardPaddingH = 16.0;
  static const cardPaddingV = 14.0;
  static const borderWidth = 1.0;
  static const swipeActionWidth = 56.0;
  static const swipeActionGap = 6.0;
  static const tapTarget = 48.0;
  static const checkSize = 22.0;
  static const daySize = 36.0;
  static const sheetRadius = 18.0;
  static const tileRadius = 14.0;
  static const tileHeight = 92.0;
  static const tileGap = 10.0;

  // Width caps, so a tablet shows a readable column instead of stretched rows
  static const maxContentWidth = 620.0;
  static const maxSheetWidth = 420.0;

  // Motion
  static const quick = Duration(milliseconds: 180);
  static const swap = Duration(milliseconds: 140);
  static const curve = Curves.easeOut;
}

/// The four meanings a foreground colour can carry. Widgets name a tone;
/// only [BrandedTone.resolve] knows which colour that is.
enum BrandedTone {
  /// Primary reading colour.
  primary,

  /// Supporting text, icons and hairlines.
  muted,

  /// Drawn on top of a filled shape.
  inverted,

  /// Destructive affordances.
  danger;

  Color resolve(ColorScheme scheme) => switch (this) {
    BrandedTone.primary => scheme.onSurface,
    BrandedTone.muted => scheme.onSurfaceVariant,
    BrandedTone.inverted => scheme.onPrimary,
    BrandedTone.danger => scheme.error,
  };
}
