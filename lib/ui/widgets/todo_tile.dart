import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'task_actions.dart';

/// One task, on its own bordered card, always a single line. Swipe either way
/// for buttons, double tap for all of them, drag the grip to reorder.
class TodoTile extends ConsumerWidget {
  const TodoTile({
    super.key,
    required this.todo,
    required this.index,
    required this.swipeGroup,
  });

  final Todo todo;

  /// Position in the list, which the drag handle needs.
  final int index;

  final BrandedSwipeGroup swipeGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BrandedSwipeActions(
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
    child: BrandedCard(
      recessed: todo.done,
      leading: todo.repeats
          ? const BrandedIcon(
              Icons.repeat_rounded,
              size: BrandedIconSize.small,
              tone: BrandedTone.muted,
            )
          : null,
      onDoubleTap: () => showTaskActions(context, ref, todo),
      // Only open tasks can move; completed ones are ranked by when they were
      // finished, so a handle there would promise something it cannot do.
      trailing: todo.done ? null : BrandedDragHandle(index: index),
      child: BrandedText(
        todo.firstLine,
        struck: todo.done,
        tone: todo.done ? BrandedTone.muted : BrandedTone.primary,
        maxLines: 1,
      ),
    ),
  );
}
