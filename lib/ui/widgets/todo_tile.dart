import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'attention_sheet.dart';
import 'task_actions.dart';
import 'todo_card.dart';

/// One task in the list: its [TodoCard], with swipe buttons either way and
/// a press-and-hold lift to reorder. The circle marks it done. A calling
/// card is the one card whose tap puts up the attention sheet.
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
    final card = TodoCard(
      todo: todo,
      calling: calling,
      // A calling card answers with its sheet; any other opens to be read.
      onTap: calling
          ? () => showAttentionSheet(context, ref, todo)
          : () => openTask(context, todo),
      onToggle: () => ref.read(todosProvider.notifier).toggle(todo),
    );

    return BrandedSwipeActions(
      group: swipeGroup,
      id: todo.key,
      leading: [
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
        // For developers: rings this task's reminder ten seconds from now.
        if (ref.watch(developerModeProvider))
          BrandedSwipeAction(
            icon: Icons.alarm_on_rounded,
            label: 'Rehearse reminder',
            onTap: () => rehearseReminder(context, ref, todo),
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
