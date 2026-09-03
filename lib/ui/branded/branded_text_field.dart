import 'package:flutter/material.dart';

import 'branded_text.dart';

/// The only text input in the app: borderless, brand colours, no fill.
class BrandedTextField extends StatelessWidget {
  const BrandedTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = BrandedText.styleFor(BrandedTextRole.body);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.done,
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
