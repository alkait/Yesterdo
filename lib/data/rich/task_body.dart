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
    this.home,
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

  /// Where a ticked item stood among its list before it sank, counted from
  /// the list's first item, so that unticked it can go back to about
  /// there. Null for an item that has not sunk.
  final int? home;

  /// The file name of the picture, for an image block; null otherwise.
  final String? image;

  bool get isCheck => kind == BlockKind.check;
  bool get isImage => kind == BlockKind.image;
  bool get hasText => !isImage;
  String get text => content.text;

  Block copyWith({
    BlockKind? kind,
    StyledText? content,
    bool? checked,
    int? home,
    bool clearHome = false,
  }) {
    final newKind = kind ?? this.kind;
    return Block(
      kind: newKind,
      content: content ?? this.content,
      checked: newKind == BlockKind.check ? (checked ?? this.checked) : false,
      image: newKind == BlockKind.image ? image : null,
      home: clearHome || newKind != BlockKind.check ? null : home ?? this.home,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'k': kind.name,
    if (checked) 'c': true,
    if (home != null) 'h': home,
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
      home: json['h'] as int?,
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

  /// The words as they are handed to another app: a line per block, a
  /// checklist item headed by its box, pictures left out. Only the words
  /// cross, never the day, the time or the repeat.
  String get shareText => blocks
      .where((block) => block.hasText)
      .map(
        (block) => switch (block.kind) {
          BlockKind.check => '${block.checked ? '☑' : '☐'} ${block.text}',
          _ => block.text,
        },
      )
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
  /// The opening line of words, which is all a notification, a widget or a
  /// banner has room for. A body that is pictures alone has none, and says
  /// so.
  String get firstLine {
    final text = plainText;
    final wrap = text.indexOf('\n');
    final line = wrap == -1 ? text : text.substring(0, wrap);
    return line.isEmpty && images.isNotEmpty ? 'Picture' : line;
  }

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

  /// The block at [from] moved to [to], its place once the others have
  /// closed over where it was. Nothing else changes: a block keeps its
  /// kind, its tick and its styles wherever it lands.
  TaskBody reordered(int from, int to) {
    final moved = [...blocks];
    final block = moved.removeAt(from);
    moved.insert(to, block);
    return TaskBody(moved);
  }

  /// The item at [index] ticked or unticked, and settled: a ticked item
  /// sinks to the foot of its list, under the others ticked before it,
  /// remembering where it stood; an unticked one goes back to about there,
  /// among the open items, or to their foot when its place is past them.
  /// The list is the run of items standing together; a paragraph or a
  /// picture bounds it.
  TaskBody ticked(int index) {
    final (start, end) = runAround(index);
    final was = blocks[index];
    final run = [
      for (var at = start; at < end; at++)
        if (at != index) blocks[at],
    ];
    final open = run.where((block) => !block.checked).length;
    final Block item;
    final int landing;
    if (!was.checked) {
      item = was.copyWith(checked: true, home: index - start);
      landing = run.length;
    } else {
      item = was.copyWith(checked: false, clearHome: true);
      landing = (was.home ?? open).clamp(0, open);
    }
    run.insert(landing, item);
    return TaskBody([
      ...blocks.sublist(0, start),
      ...run,
      ...blocks.sublist(end),
    ]);
  }

  /// Every item open again and back where it stood before it sank: the
  /// body as it was written, which is what a rule holds. The last to sink
  /// rises first, so each lands where it left from. A ticked item that
  /// never sank, as one ticked in the editor when that could be done, is
  /// opened where it stands.
  TaskBody unticked() {
    var body = TaskBody([
      for (final block in blocks)
        block.checked && block.home == null
            ? block.copyWith(checked: false)
            : block,
    ]);
    while (true) {
      final last = body.blocks.lastIndexWhere((block) => block.checked);
      if (last == -1) return body;
      body = body.ticked(last);
    }
  }

  /// These words with the ticks of [old] put back on them, for a showing
  /// whose series has been given new words: an item still there under the
  /// same words stays ticked, in the order it was ticked in, and anything
  /// else is open.
  TaskBody withTicksOf(TaskBody old) {
    var body = unticked();
    for (final was in old.blocks.where((block) => block.checked)) {
      final at = body.blocks.indexWhere(
        (block) => block.isCheck && !block.checked && block.text == was.text,
      );
      if (at != -1) body = body.ticked(at);
    }
    return body;
  }

  /// Where the checklist holding [index] begins and ends: the first index
  /// in it, and the one past its last.
  (int, int) runAround(int index) {
    var start = index;
    while (start > 0 && blocks[start - 1].isCheck) {
      start--;
    }
    var end = index + 1;
    while (end < blocks.length && blocks[end].isCheck) {
      end++;
    }
    return (start, end);
  }

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
