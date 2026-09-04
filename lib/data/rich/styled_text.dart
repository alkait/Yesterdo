import 'style_run.dart';

/// Text with styled runs laid over it. Immutable; every change returns a new
/// one. The runs are kept sorted, non-overlapping, non-empty, and merged
/// wherever neighbours carry the same styles, so two texts that look the
/// same have the same runs.
class StyledText {
  StyledText(this.text, [List<StyleRun> runs = const <StyleRun>[]])
    : runs = _normalise(runs, text.length);

  static final empty = StyledText('');

  final String text;
  final List<StyleRun> runs;

  bool get isPlain => runs.isEmpty;
  int get length => text.length;

  /// The styles in force at [offset], which is what typing there would get.
  /// A caret at the very end of a run is still inside it, so a word typed
  /// straight after bold text stays bold.
  Styles stylesAt(int offset) {
    for (final run in runs) {
      if (offset > run.start && offset <= run.end) return run.styles;
    }
    return Styles.none;
  }

  /// The styles shared by every character in [start] to [end], or what is
  /// in force at [start] for an empty range.
  Styles stylesIn(int start, int end) {
    if (start == end) return stylesAt(start);
    Styles? shared;
    for (var at = start; at < end; at++) {
      final here = _styleOfCharacter(at);
      shared = shared == null ? here : _common(shared, here);
    }
    return shared ?? Styles.none;
  }

  Styles _styleOfCharacter(int at) {
    for (final run in runs) {
      if (at >= run.start && at < run.end) return run.styles;
    }
    return Styles.none;
  }

  static Styles _common(Styles a, Styles b) => Styles(
    bold: a.bold && b.bold,
    italic: a.italic && b.italic,
    underline: a.underline && b.underline,
    highlight: a.highlight == b.highlight ? a.highlight : null,
    link: a.link == b.link ? a.link : null,
  );

  /// Rewrites the styles of [start] to [end] through [change], leaving the
  /// rest alone.
  StyledText restyle(int start, int end, Styles Function(Styles) change) {
    if (start >= end) return this;
    final out = <StyleRun>[];
    // Everything, cut at the edges of the range, then the range restyled
    // character-run by character-run.
    for (final run in _runsCoveringAll()) {
      if (run.end <= start || run.start >= end) {
        out.add(run);
        continue;
      }
      if (run.start < start) {
        out.add(run.copyWith(end: start));
      }
      final innerStart = run.start > start ? run.start : start;
      final innerEnd = run.end < end ? run.end : end;
      out.add(
        StyleRun(start: innerStart, end: innerEnd, styles: change(run.styles)),
      );
      if (run.end > end) {
        out.add(run.copyWith(start: end));
      }
    }
    return StyledText(text, out);
  }

  /// The runs with plain gaps filled in as runs of no style, so the whole
  /// text is covered.
  List<StyleRun> _runsCoveringAll() {
    final out = <StyleRun>[];
    var at = 0;
    for (final run in runs) {
      if (run.start > at) {
        out.add(StyleRun(start: at, end: run.start, styles: Styles.none));
      }
      out.add(run);
      at = run.end;
    }
    if (at < text.length) {
      out.add(StyleRun(start: at, end: text.length, styles: Styles.none));
    }
    return out;
  }

  /// The text after an edit that replaced [start] to [end] with
  /// [replacement], its runs shifted to follow. Words typed inside a run
  /// take its style; words typed at a run's very end take it too, unless
  /// [typed] says otherwise, which is what the format bar sets.
  StyledText replaced(int start, int end, String replacement, {Styles? typed}) {
    final newText = text.replaceRange(start, end, replacement);
    final delta = replacement.length - (end - start);
    final out = <StyleRun>[];
    for (final run in runs) {
      if (run.end <= start) {
        // Wholly before the edit. A run ending exactly where the edit
        // begins grows over the typed words when they carry its style.
        final continues =
            run.end == start &&
            start == end &&
            (typed ?? run.styles) == run.styles;
        out.add(continues ? run.copyWith(end: run.end + delta) : run);
      } else if (run.start >= end) {
        // Wholly after: shifted along.
        out.add(run.copyWith(start: run.start + delta, end: run.end + delta));
      } else if (run.start < start && run.end > end) {
        // The edit sits inside the run, which stretches or shrinks around it.
        out.add(run.copyWith(end: run.end + delta));
      } else {
        // The run overlaps an edge of the edit: the overlapped part goes.
        final head = run.start < start ? run.copyWith(end: start) : null;
        final tail = run.end > end
            ? run.copyWith(
                start: start + replacement.length,
                end: run.end + delta,
              )
            : null;
        if (head != null) out.add(head);
        if (tail != null) out.add(tail);
      }
    }
    var result = StyledText(newText, out);
    // Typed words that took no run of their own, but were meant to be
    // styled, get one.
    if (typed != null && !typed.isPlain && replacement.isNotEmpty) {
      final already = result.stylesIn(start, start + replacement.length);
      if (already != typed) {
        result = result.restyle(
          start,
          start + replacement.length,
          (_) => typed,
        );
      }
    }
    return result;
  }

  /// The part from [start] to [end], runs re-based to it.
  StyledText slice(int start, [int? end]) {
    final stop = end ?? text.length;
    return StyledText(text.substring(start, stop), [
      for (final run in runs)
        if (run.end > start && run.start < stop)
          StyleRun(
            start: (run.start < start ? start : run.start) - start,
            end: (run.end > stop ? stop : run.end) - start,
            styles: run.styles,
          ),
    ]);
  }

  /// This followed by [other].
  StyledText operator +(StyledText other) => StyledText(text + other.text, [
    ...runs,
    for (final run in other.runs)
      run.copyWith(start: run.start + length, end: run.end + length),
  ]);

  Map<String, Object?> toJson() => <String, Object?>{
    't': text,
    if (runs.isNotEmpty) 'r': [for (final run in runs) run.toJson()],
  };

  factory StyledText.fromJson(Map<String, Object?> json) =>
      StyledText(json['t'] as String? ?? '', [
        for (final run in (json['r'] as List?) ?? const [])
          StyleRun.fromJson((run as Map).cast<String, Object?>()),
      ]);

  static List<StyleRun> _normalise(List<StyleRun> runs, int length) {
    final sorted = [
      for (final run in runs)
        if (run.start < run.end && run.start < length && !run.styles.isPlain)
          run.copyWith(end: run.end > length ? length : run.end),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <StyleRun>[];
    for (final run in sorted) {
      if (merged.isNotEmpty) {
        final last = merged.last;
        if (last.end == run.start && last.styles == run.styles) {
          merged[merged.length - 1] = last.copyWith(end: run.end);
          continue;
        }
        assert(run.start >= last.end, 'runs never overlap: $runs');
      }
      merged.add(run);
    }
    return List.unmodifiable(merged);
  }

  @override
  bool operator ==(Object other) =>
      other is StyledText &&
      other.text == text &&
      other.runs.length == runs.length &&
      [for (var i = 0; i < runs.length; i++) runs[i] == other.runs[i]]
          .every((same) => same);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(runs));

  @override
  String toString() => 'StyledText("$text", $runs)';
}
