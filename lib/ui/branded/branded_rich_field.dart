import 'package:flutter/material.dart';

import 'branded_rich_controller.dart';
import 'branded_text.dart';

/// A text field that paints its styled runs in place: the writing surface
/// of the editor. Borderless and brand-coloured like [BrandedTextField],
/// but driven by a [BrandedRichController].
class BrandedRichField extends StatelessWidget {
  const BrandedRichField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hint = '',
    this.role = BrandedTextRole.body,
    this.struck = false,
  });

  final BrandedRichController controller;
  final FocusNode focusNode;
  final String hint;
  final BrandedTextRole role;

  /// A line through the words, for a ticked checklist item.
  final bool struck;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => _field(context, value.text),
      );

  Widget _field(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final style = BrandedText.styleFor(role).copyWith(
      color: struck ? scheme.onSurfaceVariant : scheme.onSurface,
      decoration: struck ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: scheme.onSurfaceVariant,
      decorationThickness: 1.5,
    );
    return TextField(
      textDirection: brandedTextDirection(text),
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: scheme.onSurface,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        hintText: hint,
        hintStyle: style.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
