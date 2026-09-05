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
  static const cardGap = 12.0;
  static const cardPaddingH = 16.0;
  static const cardPaddingV = 10.0;
  static const cardMinHeight = 44.0;

  /// How many lines of words a card shows before ellipsising.
  static const cardLines = 2;
  static const borderWidth = 1.0;

  /// The one shadow in the app: a touch under each open card, so it lifts
  /// off the page. Soft, short and faint.
  static const shadowBlur = 6.0;
  static const shadowOffset = Offset(0, 2);
  static const shadowAlpha = 0.07;
  static const swipeActionWidth = 56.0;
  static const swipeActionGap = 6.0;
  static const tapTarget = 48.0;
  static const checkSize = 22.0;

  /// The box on a checklist item, drawn larger than the selection circle so
  /// it reads at a glance and is easy to hit.
  static const checkBoxSize = 26.0;
  static const checkBoxBorder = 2.0;

  /// The tappable box's height: one body line with its padding, so the
  /// circle's centre lines up with the first line of the words beside it.
  static const checkBoxHitHeight = 34.0;
  static const daySize = 36.0;
  static const sheetRadius = 18.0;
  static const tileRadius = 14.0;
  static const tileHeight = 92.0;
  static const tileGap = 10.0;
  static const wheelHeight = 200.0;
  static const imageMaxHeight = 320.0;
  static const imageMaxZoom = 6.0;
  static const thumbnailSize = 44.0;
  static const thumbnailRadius = 8.0;
  static const wheelMinuteStep = 5;

  /// How much of the accent a calling card's face takes at the top of a
  /// breath. Enough to be seen, not enough to shout.
  static const callingTint = 0.10;

  // Width caps, so a tablet shows a readable column instead of stretched rows
  static const maxContentWidth = 620.0;
  static const maxSheetWidth = 420.0;

  /// How fast a sideways flick has to be to count as one, in points a second,
  /// and how far a slow pull has to go instead.
  static const flingVelocity = 250.0;
  static const swipeDistance = 72.0;

  // Motion
  static const quick = Duration(milliseconds: 180);
  static const swap = Duration(milliseconds: 140);

  /// One day sliding out and the next sliding in.
  static const turn = Duration(milliseconds: 260);
  static const curve = Curves.easeOut;

  /// One in-and-out of a calling card's pulse.
  static const breath = Duration(milliseconds: 1400);
  static const breathCurve = Curves.easeInOut;
}

/// The five meanings a foreground colour can carry. Widgets name a tone;
/// only [BrandedTone.resolve] knows which colour that is.
enum BrandedTone {
  /// Primary reading colour.
  primary,

  /// Supporting text, icons and hairlines.
  muted,

  /// Drawn on top of a filled shape.
  inverted,

  /// Destructive affordances.
  danger,

  /// The look's own colour, for the one thing asking to be noticed.
  accent;

  Color resolve(ColorScheme scheme) => switch (this) {
    BrandedTone.primary => scheme.onSurface,
    BrandedTone.muted => scheme.onSurfaceVariant,
    BrandedTone.inverted => scheme.onPrimary,
    BrandedTone.danger => scheme.error,
    BrandedTone.accent => scheme.primary,
  };
}
