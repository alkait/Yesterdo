import 'dart:convert';

import 'styled_text.dart';

/// What a block is: plain words, or an item on a checklist.
enum BlockKind { paragraph, check }

/// One block of a task's body: a paragraph or a checklist item.
class Block {
  const Block({
    required this.kind,
    required this.content,
    this.checked = false,
  });

  Block.paragraph(String text)
    : this(kind: BlockKind.paragraph, content: StyledText(text));

  final BlockKind kind;
  final StyledText content;

  /// Ticked. Only a checklist item can be.
  final bool checked;

  bool get isCheck => kind == BlockKind.check;
  String get text => content.text;

  Block copyWith({BlockKind? kind, StyledText? content, bool? checked}) =>
      Block(
        kind: kind ?? this.kind,
        content: content ?? this.content,
        checked: kind == BlockKind.paragraph
            ? false
            : (checked ?? this.checked),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'k': kind.name,
    if (checked) 'c': true,
    ...content.toJson(),
  };

  factory Block.fromJson(Map<String, Object?> json) => Block(
    kind: BlockKind.values.asNameMap()[json['k']] ?? BlockKind.paragraph,
    checked: json['c'] == true,
    content: StyledText.fromJson(json),
  );
}

/// A task's words in full: blocks of styled text, some of them checklist
/// items. Stored as JSON in its own column; the plain text beside it is
/// derived from here and never the other way round.
class TaskBody {
  TaskBody(List<Block> blocks)
    : blocks = List.unmodifiable(
        blocks.isEmpty ? [Block.paragraph('')] : blocks,
      );

  /// Plain words, one paragraph per line.
  factory TaskBody.plain(String text) =>
      TaskBody([for (final line in text.split('\n')) Block.paragraph(line)]);

  factory TaskBody.decode(String json) => TaskBody([
    for (final block in jsonDecode(json) as List)
      Block.fromJson((block as Map).cast<String, Object?>()),
  ]);

  final List<Block> blocks;

  String encode() => jsonEncode([for (final block in blocks) block.toJson()]);

  /// The words with every style stripped, blocks joined by line breaks.
  /// This is what the plain `title` column holds.
  String get plainText => blocks.map((block) => block.text).join('\n');

  bool get hasWords => blocks.any((block) => block.text.trim().isNotEmpty);

  Block get first => blocks.first;

  /// How many checklist items there are, and how many are ticked.
  (int done, int total) get checklistProgress {
    final items = blocks.where((block) => block.isCheck);
    return (items.where((block) => block.checked).length, items.length);
  }

  TaskBody withBlock(int index, Block block) => TaskBody([
    for (final (at, each) in blocks.indexed) at == index ? block : each,
  ]);

  TaskBody toggled(int index) =>
      withBlock(index, blocks[index].copyWith(checked: !blocks[index].checked));

  /// Trailing empty paragraphs trimmed, so a body ends where the words do.
  TaskBody trimmed() {
    var end = blocks.length;
    while (end > 1 && blocks[end - 1].text.trim().isEmpty) {
      end--;
    }
    return TaskBody(blocks.sublist(0, end));
  }
}
