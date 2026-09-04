import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/rich/styled_text.dart';
import 'brand.dart';
import 'branded_rich_controller.dart';
import 'branded_text.dart';

/// Styled words on screen, read-only: the runs painted, the links tappable.
/// The rich counterpart of [BrandedText], sharing its ramp and its rule on
/// reading direction.
class BrandedRichText extends StatefulWidget {
  const BrandedRichText(
    this.content, {
    super.key,
    this.role = BrandedTextRole.body,
    this.tone = BrandedTone.primary,
    this.struck = false,
    this.maxLines,
    this.onLink,
  });

  final StyledText content;
  final BrandedTextRole role;
  final BrandedTone tone;
  final bool struck;
  final int? maxLines;

  /// Called with the address when a link is tapped. Links are inert
  /// without it.
  final ValueChanged<String>? onLink;

  @override
  State<BrandedRichText> createState() => _BrandedRichTextState();
}

class _BrandedRichTextState extends State<BrandedRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<TapGestureRecognizer>? _recognizersFor(StyledText content) {
    _release();
    if (widget.onLink == null) return null;
    for (final link in BrandedRichController.links(content)) {
      _recognizers.add(
        TapGestureRecognizer()..onTap = () => widget.onLink!(link),
      );
    }
    return _recognizers;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = BrandedText.styleFor(widget.role).copyWith(
      color: widget.tone.resolve(scheme),
      decoration: widget.struck
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      decorationColor: BrandedTone.muted.resolve(scheme),
      decorationThickness: 1.5,
    );
    return AnimatedDefaultTextStyle(
      duration: Brand.quick,
      curve: Brand.curve,
      style: style,
      child: Text.rich(
        BrandedRichController.spanFor(
          widget.content,
          context: context,
          style: style,
          recognizers: _recognizersFor(widget.content),
        ),
        textDirection: brandedTextDirection(widget.content.text),
        maxLines: widget.maxLines,
        overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}
