import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'brand.dart';

/// Scripts written right to left. Checked before the general letter test, so
/// an Arabic or Hebrew letter is never mistaken for a left-to-right one.
final _rightToLeftLetter = RegExp(
  r'[\u0590-\u05FF\u0600-\u06FF\u0700-\u074F\u0750-\u077F'
  r'\u0780-\u07BF\u07C0-\u07FF\u0800-\u085F\u08A0-\u08FF'
  r'\uFB1D-\uFDFF\uFE70-\uFEFF]',
);

final _anyLetter = RegExp(r'\p{L}', unicode: true);

/// Reading direction for a piece of text, from its first strong letter.
///
/// Digits, punctuation, spaces and emoji carry no direction of their own, so
/// they are skipped rather than decided on. That is what separates this from
/// looking at the first character: `"1. مرحبا"` and `"🎉 مرحبا"` both read
/// right to left, and `"١٢٣ Hello"` still reads left to right.
TextDirection brandedTextDirection(String text) {
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    if (!_anyLetter.hasMatch(character)) continue;
    return _rightToLeftLetter.hasMatch(character)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
  return TextDirection.ltr;
}

/// The jobs text does in this app. Sizes and weights live here and nowhere
/// else.
enum BrandedTextRole {
  display,
  title,
  body,
  action,
  label,
  caption,
  wheel,
  glyph,
}

/// The only way to put text on screen.
class BrandedText extends StatelessWidget {
  const BrandedText(
    this.data, {
    super.key,
    this.role = BrandedTextRole.body,
    this.tone = BrandedTone.primary,
    this.struck = false,
    this.align,
    this.maxLines,
  });

  final String data;
  final BrandedTextRole role;
  final BrandedTone tone;

  /// Draws a line through the text, animated so a change reads as an action.
  final bool struck;

  final TextAlign? align;

  /// Ellipsised past this many lines. Unlimited when null.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedDefaultTextStyle(
      duration: Brand.quick,
      curve: Brand.curve,
      style: styleFor(role).copyWith(
        color: tone.resolve(scheme),
        decoration: struck ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: BrandedTone.muted.resolve(scheme),
        decorationThickness: 1.5,
      ),
      child: Text(
        data,
        textAlign: align,
        // Laid out in the direction the words themselves read, so an Arabic
        // task sits against the right edge of its card.
        textDirection: brandedTextDirection(data),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }

  /// The type ramp. Shared with [BrandedTextField] so input matches body
  /// text exactly.
  static TextStyle styleFor(BrandedTextRole role) => switch (role) {
    BrandedTextRole.display => const TextStyle(
      fontFamily: AppTheme.displayFamily,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    BrandedTextRole.title => const TextStyle(
      fontFamily: AppTheme.displayFamily,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    BrandedTextRole.body => const TextStyle(fontSize: 17, height: 1.3),
    BrandedTextRole.action => const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    BrandedTextRole.label => const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
    ),
    BrandedTextRole.caption => const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
    // The figures on a picker wheel.
    BrandedTextRole.wheel => const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w400,
    ),
    // A word standing in for an icon: small, heavy, spaced.
    BrandedTextRole.glyph => const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      height: 1.2,
    ),
  };
}
