import 'package:flutter/material.dart';

import '../../data/rich/style_run.dart';
import '../../data/rich/styled_text.dart';
import '../../data/rich/task_body.dart';
import '../branded/branded.dart';

/// The writing surface: one styled field per block, stacked, with pictures
/// between. Return at the
/// end of a block starts a new one of the same kind; on an empty checklist
/// item it ends the list instead. Backspace at the start of a block joins
/// it onto the one above. The format bar drives whichever block has the
/// caret, through [BodyEditorState].
class BodyEditor extends StatefulWidget {
  const BodyEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.imagesDirectory,
    this.hint = '',
  });

  final TaskBody initial;

  /// Where the pictures are.
  final String imagesDirectory;

  /// Called with the whole body after every change, and whenever the
  /// caret's styles change, so the bar can follow.
  final ValueChanged<TaskBody> onChanged;

  /// Shown in the first block while the body is empty.
  final String hint;

  @override
  State<BodyEditor> createState() => BodyEditorState();
}

class _Entry {
  _Entry({
    required this.kind,
    required this.checked,
    required this.controller,
    this.image,
  }) : focus = FocusNode();

  final Key key = UniqueKey();
  BlockKind kind;
  bool checked;
  final BrandedRichController controller;
  final FocusNode focus;

  /// The picture, for an image block. Such a block has no words and takes
  /// no caret.
  final String? image;

  bool get isImage => image != null;

  Block get block => isImage
      ? Block.image(image!)
      : Block(
          kind: kind,
          content: controller.content,
          checked: kind == BlockKind.check && checked,
        );

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class BodyEditorState extends State<BodyEditor> {
  final _entries = <_Entry>[];

  @override
  void initState() {
    super.initState();
    for (final block in widget.initial.blocks) {
      _entries.add(_entryFor(block));
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  _Entry _entryFor(Block block) {
    late final _Entry entry;
    entry = _Entry(
      kind: block.kind,
      checked: block.checked,
      image: block.image,
      controller: BrandedRichController(
        content: block.content,
        guarded: true,
        onSplit: (after) => _split(entry, after),
        onBackspaceAtStart: () => _join(entry),
      ),
    );
    entry.controller.addListener(_announce);
    entry.focus.addListener(_announce);
    return entry;
  }

  TaskBody get body => TaskBody([for (final entry in _entries) entry.block]);

  /// The block that had the caret last. A sheet put up over the editor
  /// takes the caret with it, and the bar still means this block when the
  /// sheet comes down.
  _Entry? _lastFocused;

  void _announce() {
    for (final entry in _entries) {
      if (entry.focus.hasFocus) _lastFocused = entry;
    }
    widget.onChanged(body);
  }

  /// The block with the caret, or the last one that had it.
  _Entry? get _focused {
    for (final entry in _entries) {
      if (entry.focus.hasFocus) return entry;
    }
    return _entries.contains(_lastFocused) ? _lastFocused : null;
  }

  /// What the bar should show: null while no block has the caret.
  Styles? get currentStyles => _focused?.controller.current;

  bool get focusedIsChecklist => _focused?.kind == BlockKind.check;

  /// The link at the caret, if the words there are one.
  String? get currentLink => _focused?.controller.current.link;

  /// Puts the caret at the very end of the last block with words. A body
  /// ending in a picture gets a paragraph to write in after it.
  void focusEnd() {
    if (_entries.last.isImage) {
      setState(() => _entries.add(_entryFor(Block.paragraph(''))));
      WidgetsBinding.instance.addPostFrameCallback((_) => focusEnd());
      return;
    }
    final last = _entries.last;
    last.focus.requestFocus();
    last.controller.setContent(
      last.controller.content,
      caret: last.controller.content.length,
    );
  }

  /// Puts a picture in after the block with the caret, or at the end, and
  /// sees that there is a paragraph after it to carry on writing in.
  void insertImage(String image) {
    final focused = _focused;
    final at = focused == null
        ? _entries.length
        : _entries.indexOf(focused) + 1;
    final picture = _entryFor(Block.image(image));
    setState(() {
      _entries.insert(at, picture);
      if (at + 1 >= _entries.length || _entries[at + 1].isImage) {
        _entries.insert(at + 1, _entryFor(Block.paragraph('')));
      }
    });
    final next = _entries[at + 1];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      next.focus.requestFocus();
      next.controller.setContent(next.controller.content, caret: 0);
    });
    _announce();
  }

  /// Takes a picture out. The file itself is left for the sweep, since
  /// Cancel may yet put the picture back.
  void _removeImage(_Entry entry) {
    setState(() => _entries.remove(entry));
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
    _announce();
  }

  void toggleBold() => _focused?.controller.toggleBold();
  void toggleItalic() => _focused?.controller.toggleItalic();
  void toggleUnderline() => _focused?.controller.toggleUnderline();
  void cycleHighlight() => _focused?.controller.cycleHighlight();
  void setLink(String? url) => _focused?.controller.setLink(url);

  /// Turns the block with the caret into a checklist item, or back.
  void toggleChecklist() {
    final entry = _focused;
    if (entry == null) return;
    setState(() {
      entry.kind = entry.kind == BlockKind.check
          ? BlockKind.paragraph
          : BlockKind.check;
      if (entry.kind == BlockKind.paragraph) entry.checked = false;
    });
    _announce();
  }

  void _tick(_Entry entry) {
    setState(() => entry.checked = !entry.checked);
    _announce();
  }

  /// Return was pressed: the words after the caret go into a new block
  /// below, of the same kind. On an empty checklist item, the list ends and
  /// the item becomes a paragraph instead.
  void _split(_Entry entry, StyledText after) {
    if (entry.kind == BlockKind.check &&
        entry.controller.content.text.isEmpty &&
        after.text.isEmpty) {
      setState(() {
        entry.kind = BlockKind.paragraph;
        entry.checked = false;
      });
      _announce();
      return;
    }
    final index = _entries.indexOf(entry);
    final next = _entryFor(
      Block(kind: entry.kind, content: after, checked: false),
    );
    setState(() => _entries.insert(index + 1, next));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      next.focus.requestFocus();
      next.controller.setContent(after, caret: 0);
    });
    _announce();
  }

  /// Backspace at the very start: the block's words join the end of the
  /// one above, and the caret lands at the seam. The first block has
  /// nothing above it, so a checklist item there just becomes a paragraph.
  void _join(_Entry entry) {
    final index = _entries.indexOf(entry);
    if (index == 0) {
      if (entry.kind == BlockKind.check) {
        setState(() {
          entry.kind = BlockKind.paragraph;
          entry.checked = false;
        });
        _announce();
      }
      return;
    }
    final above = _entries[index - 1];
    // Backspace against a picture takes the picture out.
    if (above.isImage) {
      _removeImage(above);
      return;
    }
    final seam = above.controller.content.length;
    final joined = above.controller.content + entry.controller.content;
    setState(() => _entries.removeAt(index));
    above.focus.requestFocus();
    above.controller.setContent(joined, caret: seam);
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
    _announce();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, entry) in _entries.indexed)
        if (entry.isImage)
          _ImageRow(
            key: entry.key,
            path: '${widget.imagesDirectory}/${entry.image}',
            onRemove: () => _removeImage(entry),
          )
        else
          _BlockRow(
            key: entry.key,
            entry: entry,
            hint: index == 0 && _entries.length == 1 ? widget.hint : '',
            onTick: () => _tick(entry),
          ),
    ],
  );
}

/// A picture in the editor, with a way to take it out.
class _ImageRow extends StatelessWidget {
  const _ImageRow({super.key, required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Stack(
      children: [
        BrandedImage(path: path),
        Positioned(
          top: 0,
          right: 0,
          child: BrandedIconButton(
            key: ValueKey('remove-image-$path'),
            icon: Icons.close_rounded,
            label: 'Remove picture',
            size: BrandedIconSize.medium,
            onTap: onRemove,
          ),
        ),
      ],
    ),
  );
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    super.key,
    required this.entry,
    required this.hint,
    required this.onTick,
  });

  final _Entry entry;
  final String hint;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context) {
    final field = BrandedRichField(
      controller: entry.controller,
      focusNode: entry.focus,
      hint: hint,
      struck: entry.kind == BlockKind.check && entry.checked,
    );
    if (entry.kind != BlockKind.check) return field;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: Brand.gap),
          child: BrandedCheckBox(checked: entry.checked, onTap: onTick),
        ),
        Expanded(child: field),
      ],
    );
  }
}
