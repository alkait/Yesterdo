import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'attention_sheet.dart';
import 'task_actions.dart';

/// One task, on its own bordered card, always a single line. Swipe either way
/// for buttons, press and hold to reorder. A calling card is the one card
/// that takes a tap, which puts up the attention sheet.
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
      leading: todo.repeats
          ? const BrandedIcon(
              Icons.repeat_rounded,
              size: BrandedIconSize.small,
              tone: BrandedTone.muted,
            )
          : null,
      trailing: todo.due == null
          ? null
          : _DueMark(todo: todo, calling: calling),
      child: BrandedText(
        todo.firstLine,
        struck: todo.done,
        tone: todo.done ? BrandedTone.muted : BrandedTone.primary,
        maxLines: 1,
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

/// The time in small print at the card's trailing end, with a bell when a
/// reminder is set. Both take the accent while the card is calling.
class _DueMark extends StatelessWidget {
  const _DueMark({required this.todo, required this.calling});

  final Todo todo;
  final bool calling;

  @override
  Widget build(BuildContext context) {
    final tone = calling ? BrandedTone.accent : BrandedTone.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (todo.due!.hasReminder) ...[
          BrandedIcon(
            Icons.notifications_none_rounded,
            size: BrandedIconSize.small,
            tone: tone,
          ),
          const SizedBox(width: 4),
        ],
        BrandedText(
          todo.due!.label(
            twentyFourHour: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          role: BrandedTextRole.caption,
          tone: tone,
        ),
      ],
    );
  }
}
