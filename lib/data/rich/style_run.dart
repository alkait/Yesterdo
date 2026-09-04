/// The colours a highlight can take. Named, never a colour value; the theme
/// decides what each looks like in each look and brightness.
enum Highlight { yellow, green, blue }

/// The styles a piece of text can carry, all at once if need be.
class Styles {
  const Styles({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.highlight,
    this.link,
  });

  static const none = Styles();

  final bool bold;
  final bool italic;
  final bool underline;
  final Highlight? highlight;

  /// Where a tap goes, or null for plain words.
  final String? link;

  bool get isPlain =>
      !bold && !italic && !underline && highlight == null && link == null;

  Styles copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    Highlight? highlight,
    bool clearHighlight = false,
    String? link,
    bool clearLink = false,
  }) => Styles(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    highlight: clearHighlight ? null : (highlight ?? this.highlight),
    link: clearLink ? null : (link ?? this.link),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (bold) 'b': true,
    if (italic) 'i': true,
    if (underline) 'u': true,
    if (highlight != null) 'h': highlight!.name,
    if (link != null) 'l': link,
  };

  factory Styles.fromJson(Map<String, Object?> json) => Styles(
    bold: json['b'] == true,
    italic: json['i'] == true,
    underline: json['u'] == true,
    highlight: switch (json['h']) {
      final String name => Highlight.values.asNameMap()[name],
      _ => null,
    },
    link: json['l'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Styles &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.highlight == highlight &&
      other.link == link;

  @override
  int get hashCode => Object.hash(bold, italic, underline, highlight, link);

  @override
  String toString() => 'Styles(${toJson()})';
}

/// A stretch of a block's text, [start] up to but not including [end],
/// carrying one set of [styles]. Runs never overlap; plain text between
/// them has no run at all.
class StyleRun {
  const StyleRun({required this.start, required this.end, required this.styles})
    : assert(start <= end, 'a run runs forwards');

  final int start;
  final int end;
  final Styles styles;

  int get length => end - start;
  bool get isEmpty => start == end;

  StyleRun copyWith({int? start, int? end, Styles? styles}) => StyleRun(
    start: start ?? this.start,
    end: end ?? this.end,
    styles: styles ?? this.styles,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    's': start,
    'e': end,
    ...styles.toJson(),
  };

  factory StyleRun.fromJson(Map<String, Object?> json) => StyleRun(
    start: json['s']! as int,
    end: json['e']! as int,
    styles: Styles.fromJson(json),
  );

  @override
  bool operator ==(Object other) =>
      other is StyleRun &&
      other.start == start &&
      other.end == end &&
      other.styles == styles;

  @override
  int get hashCode => Object.hash(start, end, styles);

  @override
  String toString() => 'StyleRun($start-$end ${styles.toJson()})';
}
