/// A bullet or a box at the head of a pasted line, which says what the line
/// is: an item on a checklist, ticked or not. A list pasted in from
/// elsewhere is still a list, so its bullets become items too. The one
/// place that knows the marks.
class LineMarker {
  const LineMarker._({required this.checked, required this.length});

  final bool checked;

  /// How many characters the mark takes, indent included, so it can be
  /// taken off the front of the line.
  final int length;

  static const _ticked = ['[x] ', '[X] ', '☑ ', '☒ ', '✓ ', '✔ ', '✅ '];
  static const _open = [
    '[ ] ',
    '[] ',
    '☐ ',
    '• ',
    '- ',
    '* ',
    '– ',
    '— ',
    '· ',
    '◦ ',
    '▪ ',
    '○ ',
  ];

  /// The mark at the head of [line], or null when there is none.
  static LineMarker? of(String line) {
    final indent = line.length - line.trimLeft().length;
    final rest = line.substring(indent);
    for (final mark in _ticked) {
      if (rest.startsWith(mark)) {
        return LineMarker._(checked: true, length: indent + mark.length);
      }
    }
    for (final mark in _open) {
      if (rest.startsWith(mark)) {
        return LineMarker._(checked: false, length: indent + mark.length);
      }
    }
    return null;
  }
}
