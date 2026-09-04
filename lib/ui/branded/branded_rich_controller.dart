import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/rich/style_run.dart';
import '../../data/rich/styled_text.dart';
import 'branded_text.dart';

/// A text controller that keeps styled runs alongside the words and paints
/// them in place, so a plain text field becomes a what-you-see editor. The
/// field itself is untouched: selection, cursor, autocorrect and undo are
/// all still the system's.
///
/// Every change to the text is diffed against the last, and the runs are
/// shifted to follow. The format bar sets [typed] for what the next words
/// should carry when nothing is selected.
class BrandedRichController extends TextEditingController {
  BrandedRichController({
    StyledText? content,
    this.guarded = false,
    this.onSplit,
    this.onBackspaceAtStart,
  }) : _content = content ?? StyledText.empty,
       super(text: (guarded ? guard : '') + (content?.text ?? ''));

  /// An invisible character kept at the very start of a guarded field. The
  /// soft keyboard says nothing when backspace is pressed in an empty field,
  /// but it does delete this, and that is how the start of a block is heard.
  static const guard = '\u200B';

  final bool guarded;

  /// Called instead of putting a line break into the words: the words after
  /// the break are handed over for a new block.
  final ValueChanged<StyledText>? onSplit;

  /// Called when backspace is pressed at the very start of a guarded field.
  final VoidCallback? onBackspaceAtStart;

  int get _lead => guarded ? guard.length : 0;

  StyledText _content;

  /// The words with their runs, as they stand.
  StyledText get content => _content;

  /// Replaces the words and runs outright, as when a block is split or
  /// joined. The caret goes to [caret], or the end.
  set content(StyledText content) => setContent(content);

  void setContent(StyledText content, {int? caret}) {
    _content = content;
    _typed = null;
    final at = (caret ?? content.length).clamp(0, content.length);
    super.value = TextEditingValue(
      text: (guarded ? guard : '') + content.text,
      selection: TextSelection.collapsed(offset: at + _lead),
    );
  }

  Styles? _typed;

  /// What the next words typed at a collapsed caret will carry: whatever
  /// the bar set, else whatever is in force there.
  Styles get typed => _typed ?? _content.stylesAt(_caret);

  /// The styles the bar should show lit: shared by the selection, or in
  /// force at the caret.
  Styles get current {
    final range = _range;
    if (range == null || range.$1 == range.$2) return typed;
    return _content.stylesIn(range.$1, range.$2);
  }

  int get _caret {
    final selection = value.selection;
    final at = selection.isValid ? selection.extentOffset : text.length;
    return (at - _lead).clamp(0, _content.length);
  }

  /// The selection in the words, the guard left out.
  (int, int)? get _range {
    final selection = value.selection;
    if (!selection.isValid) return null;
    return (
      (selection.start - _lead).clamp(0, _content.length),
      (selection.end - _lead).clamp(0, _content.length),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    final old = value;
    if (guarded && !newValue.text.startsWith(guard)) {
      if (newValue.text == _content.text) {
        // Only the guard went: backspace at the very start. Put it back
        // and say so.
        super.value = TextEditingValue(
          text: guard + _content.text,
          selection: const TextSelection.collapsed(offset: 1),
        );
        onBackspaceAtStart?.call();
        return;
      }
      // The whole value was replaced, as by a paste over everything or a
      // test typing in: the guard goes back on the front.
      newValue = newValue.copyWith(
        text: guard + newValue.text,
        selection: newValue.selection.isValid
            ? newValue.selection.copyWith(
                baseOffset: newValue.selection.baseOffset + 1,
                extentOffset: newValue.selection.extentOffset + 1,
              )
            : null,
      );
    }
    if (newValue.text != old.text) {
      final (start, end, inserted) = _diff(old.text, newValue.text);
      final from = start - _lead;
      final to = end - _lead;
      final split = onSplit == null ? -1 : inserted.indexOf('\n');
      if (split != -1) {
        // A line break: everything from it on goes to a new block.
        final whole = _content.replaced(
          from,
          to,
          inserted.replaceAll('\n', ''),
          typed: _typed,
        );
        final at = from + split;
        setContent(whole.slice(0, at), caret: at);
        onSplit!(whole.slice(at));
        return;
      }
      _content = _content.replaced(from, to, inserted, typed: _typed);
      // Once words carry the style, the caret sits inside their run and
      // picks it up from there.
      _typed = null;
    } else if (newValue.selection != old.selection) {
      _typed = null;
    }
    super.value = _guardedSelection(newValue);
  }

  /// The caret is never let in front of the guard.
  TextEditingValue _guardedSelection(TextEditingValue value) {
    if (!guarded || !value.selection.isValid) return value;
    final selection = value.selection;
    if (selection.baseOffset >= _lead && selection.extentOffset >= _lead) {
      return value;
    }
    return value.copyWith(
      selection: selection.copyWith(
        baseOffset: selection.baseOffset < _lead ? _lead : selection.baseOffset,
        extentOffset: selection.extentOffset < _lead
            ? _lead
            : selection.extentOffset,
      ),
    );
  }

  /// The one stretch that changed, as where it began and ended in the old
  /// words and what stands there now.
  static (int, int, String) _diff(String before, String after) {
    var prefix = 0;
    final shortest = before.length < after.length
        ? before.length
        : after.length;
    while (prefix < shortest && before[prefix] == after[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shortest - prefix &&
        before[before.length - 1 - suffix] ==
            after[after.length - 1 - suffix]) {
      suffix++;
    }
    return (
      prefix,
      before.length - suffix,
      after.substring(prefix, after.length - suffix),
    );
  }

  /// Applies [change] to the selection, or to the words typed next when
  /// nothing is selected.
  void restyle(Styles Function(Styles) change) {
    final range = _range;
    if (range == null || range.$1 == range.$2) {
      _typed = change(typed);
    } else {
      _content = _content.restyle(range.$1, range.$2, change);
    }
    notifyListeners();
  }

  void toggleBold() => restyle((s) => s.copyWith(bold: !s.bold));
  void toggleItalic() => restyle((s) => s.copyWith(italic: !s.italic));
  void toggleUnderline() => restyle((s) => s.copyWith(underline: !s.underline));

  /// Yellow, then green, then blue, then none again.
  void cycleHighlight() => restyle((s) {
    final next = switch (s.highlight) {
      null => Highlight.yellow,
      Highlight.yellow => Highlight.green,
      Highlight.green => Highlight.blue,
      Highlight.blue => null,
    };
    return s.copyWith(highlight: next, clearHighlight: next == null);
  });

  /// Makes the selection a link, or takes the link off with null. With
  /// nothing selected the address itself is typed in as the link.
  void setLink(String? url) {
    final range = _range;
    if (url != null && (range == null || range.$1 == range.$2)) {
      final at = _caret;
      final linked = _content
          .replaced(at, at, url, typed: Styles.none)
          .restyle(at, at + url.length, (s) => s.copyWith(link: url));
      setContent(linked, caret: at + url.length);
      _typed = Styles.none;
      return;
    }
    restyle((s) => s.copyWith(link: url, clearLink: url == null));
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => TextSpan(
    style: style,
    children: [
      if (guarded) const TextSpan(text: guard),
      spanFor(_content, context: context, style: style ?? const TextStyle()),
    ],
  );

  /// The words as one span with a child per run, in the style each run
  /// asks for. Shared with the read-only rendering so both look alike.
  static TextSpan spanFor(
    StyledText content, {
    required BuildContext context,
    required TextStyle style,
    List<GestureRecognizer?>? recognizers,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final children = <InlineSpan>[];
    var at = 0;
    var index = 0;
    for (final run in content.runs) {
      if (run.start > at) {
        children.add(TextSpan(text: content.text.substring(at, run.start)));
      }
      final s = run.styles;
      children.add(
        TextSpan(
          text: content.text.substring(run.start, run.end),
          recognizer: s.link == null || recognizers == null
              ? null
              : recognizers[index++],
          style: style.copyWith(
            fontWeight: s.bold ? FontWeight.w700 : null,
            fontStyle: s.italic ? FontStyle.italic : null,
            decoration: s.underline || s.link != null
                ? TextDecoration.underline
                : null,
            decorationColor: s.link != null ? scheme.primary : null,
            color: s.link != null ? scheme.primary : null,
            backgroundColor: s.highlight == null
                ? null
                : AppTheme.highlightFor(s.highlight!, brightness),
          ),
        ),
      );
      at = run.end;
    }
    if (at < content.length) {
      children.add(TextSpan(text: content.text.substring(at)));
    }
    return TextSpan(style: style, children: children);
  }

  /// How many runs carry a link, which is how many recognizers a reader
  /// of the words needs to hand [spanFor].
  static int linkCount(StyledText content) =>
      content.runs.where((run) => run.styles.link != null).length;

  /// The addresses, in run order, to pair with the recognizers.
  static List<String> links(StyledText content) => [
    for (final run in content.runs)
      if (run.styles.link != null) run.styles.link!,
  ];
}

/// What the rich field shares with [BrandedText]: the ramp.
TextStyle richStyleFor(BrandedTextRole role) => BrandedText.styleFor(role);
