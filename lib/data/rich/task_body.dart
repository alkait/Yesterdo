import 'dart:convert';

import 'styled_text.dart';

/// What a block is: plain words, an item on a checklist, or a picture.
enum BlockKind { paragraph, check, image }

/// One block of a task's body: a paragraph, a checklist item or an image.
class Block {
  Block({
    required this.kind,
    StyledText? content,
    this.checked = false,
    this.image,
  }) : content = content ?? StyledText.empty,
       assert(
         (kind == BlockKind.image) == (image != null),
         'an image block has a picture, the others have not',
       );

  Block.paragraph(String text)
    : this(kind: BlockKind.paragraph, content: StyledText(text));

  /// A picture on its own, kept as a file named [image] in the images
  /// folder.
  Block.image(String image) : this(kind: BlockKind.image, image: image);

  final BlockKind kind;
  final StyledText content;

  /// Ticked. Only a checklist item can be.
  final bool checked;

  /// The file name of the picture, for an image block; null otherwise.
  final String? image;

  bool get isCheck => kind == BlockKind.check;
  bool get isImage => kind == BlockKind.image;
  bool get hasText => !isImage;
  String get text => content.text;

  Block copyWith({BlockKind? kind, StyledText? content, bool? checked}) {
    final newKind = kind ?? this.kind;
    return Block(
      kind: newKind,
      content: content ?? this.content,
      checked: newKind == BlockKind.check ? (checked ?? this.checked) : false,
      image: newKind == BlockKind.image ? image : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'k': kind.name,
    if (checked) 'c': true,
    if (image != null) 'f': image,
    if (!isImage) ...content.toJson(),
  };

  factory Block.fromJson(Map<String, Object?> json) {
    final kind = BlockKind.values.asNameMap()[json['k']] ?? BlockKind.paragraph;
    final image = json['f'] as String?;
    if (kind == BlockKind.image && image != null) return Block.image(image);
    return Block(
      kind: kind == BlockKind.image ? BlockKind.paragraph : kind,
      checked: json['c'] == true,
      content: StyledText.fromJson(json),
    );
  }
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

  /// The words with every style stripped, text blocks joined by line
  /// breaks, pictures left out. This is what the plain `title` column holds.
  String get plainText => blocks
      .where((block) => block.hasText)
      .map((block) => block.text)
      .join('\n');

  /// Whether there is anything worth keeping: words, or a picture.
  bool get hasWords =>
      blocks.any((block) => block.isImage || block.text.trim().isNotEmpty);

  Block get first => blocks.first;

  /// The first block with words in it, which is what a card shows. Null
  /// for a body that is pictures alone.
  Block? get firstText => blocks
      .where((block) => block.hasText && block.text.trim().isNotEmpty)
      .firstOrNull;

  /// The pictures, in order.
  List<String> get images => [for (final block in blocks) ?block.image];

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
    while (end > 1 &&
        blocks[end - 1].hasText &&
        blocks[end - 1].text.trim().isEmpty) {
      end--;
    }
    return TaskBody(blocks.sublist(0, end));
  }
}
