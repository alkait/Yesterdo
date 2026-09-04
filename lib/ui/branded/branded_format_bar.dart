import 'package:flutter/material.dart';

import '../../data/rich/style_run.dart';
import 'brand.dart';
import 'branded_divider.dart';
import 'branded_icon.dart';

/// The strip over the keyboard on the editor: bold, italic, underline,
/// highlight, link, checklist, picture. Lit where the style is in force at the
/// caret. Disabled as a whole while no block has the keyboard.
class BrandedFormatBar extends StatelessWidget {
  const BrandedFormatBar({
    super.key,
    required this.current,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onHighlight,
    required this.onLink,
    required this.onChecklist,
    required this.onImage,
    this.checklist = false,
  });

  /// What is in force where the caret is, or null with no caret anywhere.
  final Styles? current;

  /// Whether the block with the caret is a checklist item.
  final bool checklist;

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onHighlight;
  final VoidCallback onLink;
  final VoidCallback onChecklist;
  final VoidCallback onImage;

  @override
  Widget build(BuildContext context) {
    final styles = current ?? Styles.none;
    final enabled = current != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BrandedDivider.sideOf(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Key(
            key: const ValueKey('format-bold'),
            icon: Icons.format_bold_rounded,
            label: 'Bold',
            lit: styles.bold,
            enabled: enabled,
            onTap: onBold,
          ),
          _Key(
            key: const ValueKey('format-italic'),
            icon: Icons.format_italic_rounded,
            label: 'Italic',
            lit: styles.italic,
            enabled: enabled,
            onTap: onItalic,
          ),
          _Key(
            key: const ValueKey('format-underline'),
            icon: Icons.format_underlined_rounded,
            label: 'Underline',
            lit: styles.underline,
            enabled: enabled,
            onTap: onUnderline,
          ),
          _Key(
            key: const ValueKey('format-highlight'),
            icon: Icons.border_color_rounded,
            label: 'Highlight',
            lit: styles.highlight != null,
            enabled: enabled,
            onTap: onHighlight,
          ),
          _Key(
            key: const ValueKey('format-link'),
            icon: Icons.link_rounded,
            label: 'Link',
            lit: styles.link != null,
            enabled: enabled,
            onTap: onLink,
          ),
          _Key(
            key: const ValueKey('format-checklist'),
            icon: Icons.checklist_rounded,
            label: 'Checklist',
            lit: checklist,
            enabled: enabled,
            onTap: onChecklist,
          ),
          _Key(
            key: const ValueKey('format-image'),
            icon: Icons.image_outlined,
            label: 'Picture',
            lit: false,
            enabled: enabled,
            onTap: onImage,
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.icon,
    required this.label,
    required this.lit,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool lit;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: lit,
    enabled: enabled,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: Brand.tapTarget,
        height: Brand.tapTarget,
        child: Center(
          child: BrandedIcon(
            icon,
            tone: !enabled
                ? BrandedTone.muted
                : lit
                ? BrandedTone.accent
                : BrandedTone.primary,
          ),
        ),
      ),
    ),
  );
}
