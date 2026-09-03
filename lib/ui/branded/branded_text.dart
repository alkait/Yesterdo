import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'brand.dart';

/// The jobs text does in this app. Sizes and weights live here and nowhere
/// else.
enum BrandedTextRole { display, title, body, action, label, caption }

/// The only way to put text on screen.
class BrandedText extends StatelessWidget {
  const BrandedText(
    this.data, {
    super.key,
    this.role = BrandedTextRole.body,
    this.tone = BrandedTone.primary,
    this.struck = false,
    this.align,
  });

  final String data;
  final BrandedTextRole role;
  final BrandedTone tone;

  /// Draws a line through the text, animated so a change reads as an action.
  final bool struck;

  final TextAlign? align;

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
      child: Text(data, textAlign: align),
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
  };
}
