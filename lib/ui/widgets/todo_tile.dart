import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'attention_sheet.dart';
import 'task_actions.dart';

/// One task, on its own bordered card, its words on up to two lines and
/// ellipsised past that. Swipe either way for buttons, press and hold to
/// reorder. A calling card is the one card that takes a tap, which puts up
/// the attention sheet.
class TodoTile extends ConsumerWidget {
  const TodoTile({
    super.key,
    required this.todo,
    required this.index,
    required this.swipeGroup,
    this.calling = false,
  });

  final Todo todo;

  /// Position in the list, which the lift needs.
  final int index;

  final BrandedSwipeGroup swipeGroup;

  /// Its time has come and nobody has answered yet.
  final bool calling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = BrandedCard(
      recessed: todo.done,
      calling: calling,
      onTap: calling ? () => showAttentionSheet(context, ref, todo) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandedText(
            todo.title,
            role: BrandedTextRole.card,
            struck: todo.done,
            tone: todo.done ? BrandedTone.muted : BrandedTone.primary,
            maxLines: Brand.cardLines,
          ),
          // The words get the whole width. Anything else about the task
          // goes in small print underneath.
          if (todo.repeats || todo.due != null)
            _SmallPrint(todo: todo, calling: calling),
        ],
      ),
    );

    return BrandedSwipeActions(
      group: swipeGroup,
      id: todo.key,
      leading: [
        BrandedSwipeAction(
          icon: doneIconFor(todo),
          label: doneLabelFor(todo),
          onTap: () => ref.read(todosProvider.notifier).toggle(todo),
        ),
        BrandedSwipeAction(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onTap: () => editTask(context, ref, todo),
        ),
      ],
      trailing: [
        // Only an open task has anywhere to go.
        if (!todo.done)
          BrandedSwipeAction.words(
            ('NOT', 'TODAY'),
            label: 'Not today',
            onTap: () => moveTask(context, ref, todo),
          ),
        BrandedSwipeAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          tone: BrandedTone.danger,
          onTap: () => deleteTask(context, ref, todo),
        ),
      ],
      // Only open tasks can move; completed ones are ranked by when they were
      // finished, and calling ones hold the top, so lifting either would
      // promise something it cannot do.
      child: todo.done || calling
          ? card
          : BrandedDragLift(index: index, child: card),
    );
  }
}

/// The line under the words: a repeat glyph for a repeating task, a bell
/// when a reminder is set, and the time. All take the accent while the card
/// is calling.
class _SmallPrint extends StatelessWidget {
  const _SmallPrint({required this.todo, required this.calling});

  final Todo todo;
  final bool calling;

  @override
  Widget build(BuildContext context) {
    final tone = calling ? BrandedTone.accent : BrandedTone.muted;
    final due = todo.due;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
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
