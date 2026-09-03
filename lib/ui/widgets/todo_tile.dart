import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'task_actions_sheet.dart';

/// One task, on its own bordered card, always a single line. Double tap for
/// what you can do to it, drag the grip to reorder, or swipe left to delete.
class TodoTile extends ConsumerWidget {
  const TodoTile({super.key, required this.todo, required this.index});

  final Todo todo;

  /// Position in the list, which the drag handle needs.
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BrandedDismissible(
    dismissKey: ValueKey('dismiss-${todo.id}'),
    onDismissed: () => ref.read(todosProvider.notifier).remove(todo),
    child: BrandedCard(
      recessed: todo.done,
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
