import 'package:flutter/material.dart';

import '../../data/todo.dart';
import '../branded/branded.dart';

/// One task drawn as a bordered card: the done circle at its leading edge,
/// the first block of words on up to two lines, and the small print under
/// them. Knows nothing of swipes or lifting; [TodoTile] adds those, and the
/// same card flies over the list on its way to a new place.
class TodoCard extends StatelessWidget {
  const TodoCard({
    super.key,
    required this.todo,
    this.calling = false,
    this.onTap,
    this.onToggle,
  });

  final Todo todo;

  /// Its time has come and nobody has answered yet.
  final bool calling;

  final VoidCallback? onTap;

  /// Marks it done, or not done again. Without one the circle is only seen.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final first = todo.body.firstText;
    return BrandedCard(
      recessed: todo.done,
      calling: calling,
      onTap: onTap,
      leading: BrandedCheckBox(
        key: ValueKey('done-${todo.key}'),
        checked: todo.done,
        onTap: onToggle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The first block of words, styles and all. A ticked checklist
          // item reads struck; the card's one circle is for done.
          first == null
              ? const BrandedText(
                  'Picture',
                  role: BrandedTextRole.card,
                  tone: BrandedTone.muted,
                  maxLines: 1,
                )
              : BrandedRichText(
                  first.content,
                  role: BrandedTextRole.card,
                  struck: todo.done || first.checked,
                  tone: todo.done ? BrandedTone.muted : BrandedTone.primary,
                  maxLines: Brand.cardLines,
                ),
          // The words get the whole width. Anything else about the task
          // goes in small print underneath.
          if (todo.repeats ||
              todo.due != null ||
              todo.body.checklistProgress.$2 > 0)
            _SmallPrint(todo: todo, calling: calling),
        ],
      ),
    );
  }
}

/// The line under the words: how much of a checklist is ticked, a repeat
/// glyph for a repeating task, a bell when a reminder is set, and the time.
/// All take the accent while the card is calling.
class _SmallPrint extends StatelessWidget {
  const _SmallPrint({required this.todo, required this.calling});

  final Todo todo;
  final bool calling;

  @override
  Widget build(BuildContext context) {
    final tone = calling ? BrandedTone.accent : BrandedTone.muted;
    final due = todo.due;
    final (ticked, items) = todo.body.checklistProgress;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (items > 0) ...[
            BrandedText(
              '$ticked of $items',
              role: BrandedTextRole.caption,
              tone: tone,
            ),
            const SizedBox(width: Brand.gap),
          ],
          if (todo.repeats) ...[
            BrandedIcon(
              Icons.repeat_rounded,
              size: BrandedIconSize.small,
              tone: tone,
            ),
            const SizedBox(width: 6),
          ],
          if (due != null) ...[
            if (due.hasReminder) ...[
              BrandedIcon(
                Icons.notifications_none_rounded,
                size: BrandedIconSize.small,
                tone: tone,
              ),
              const SizedBox(width: 4),
            ],
            BrandedText(
              due.label(
                twentyFourHour: MediaQuery.alwaysUse24HourFormatOf(context),
              ),
              role: BrandedTextRole.caption,
              tone: tone,
            ),
          ],
        ],
      ),
    );
  }
}
