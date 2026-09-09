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
        builder: (context, _, _) => _field(context),
      );

  /// The words' own padding, kept in one place so the hint drawn over the
  /// field lands on the same line as the first words typed.
  static const _padding = EdgeInsets.symmetric(vertical: 6);

  Widget _field(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = BrandedText.styleFor(role).copyWith(
      color: struck ? scheme.onSurfaceVariant : scheme.onSurface,
      decoration: struck ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: scheme.onSurfaceVariant,
      decorationThickness: 1.5,
    );
    final field = _input(context, scheme, style);
    if (hint.isEmpty || controller.content.text.isNotEmpty) return field;

    // A guarded field always holds its invisible guard character, so as far
    // as the field is concerned it is never empty and its own hint would
    // never show. It is drawn behind instead.
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: _padding,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Text(
                  hint,
                  textDirection: brandedTextDirection(hint),
                  style: style.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
        field,
      ],
    );
  }

  Widget _input(BuildContext context, ColorScheme scheme, TextStyle style) {
    return TextField(
      textDirection: brandedTextDirection(controller.content.text),
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: scheme.onSurface,
      style: style,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: _padding,
      ),
    );
  }
}
