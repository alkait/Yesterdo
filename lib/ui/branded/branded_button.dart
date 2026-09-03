import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_text.dart';

/// A flat icon button with a full-size tap target and no ripple.
class BrandedIconButton extends StatelessWidget {
  const BrandedIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = BrandedIconSize.large,
  });

  final IconData icon;

  /// Read aloud by VoiceOver. The icon alone says nothing.
  final String label;

  final VoidCallback onTap;
  final BrandedIconSize size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: Brand.tapTarget,
        height: Brand.tapTarget,
        child: Center(child: BrandedIcon(icon, size: size)),
      ),
    ),
  );
}

/// A flat text button. No fill, no border, no ripple.
class BrandedTextButton extends StatelessWidget {
  const BrandedTextButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: BrandedText(label, role: BrandedTextRole.action),
      ),
    ),
  );
}
