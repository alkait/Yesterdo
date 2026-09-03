import 'package:flutter/material.dart';

import 'branded_text.dart';

/// The only text input in the app: borderless, brand colours, no fill.
class BrandedTextField extends StatelessWidget {
  const BrandedTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.onSubmitted,
    this.role = BrandedTextRole.body,
    this.autofocus = false,
    this.multiline = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final BrandedTextRole role;
  final bool autofocus;

  /// Grows with the text and keeps the return key as a newline.
  final bool multiline;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => _field(context, value.text),
      );

  Widget _field(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final style = BrandedText.styleFor(role);
    return TextField(
      textDirection: brandedTextDirection(text),
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLines: multiline ? null : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: scheme.onSurface,
      onSubmitted: onSubmitted,
      style: style.copyWith(color: scheme.onSurface),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        hintText: hint,
        hintStyle: style.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
