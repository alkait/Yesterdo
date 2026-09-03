import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// One task. Tap anywhere to check it, swipe left to delete it.
class TodoTile extends ConsumerWidget {
  const TodoTile({super.key, required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.read(todosProvider.notifier);

    return BrandedDismissible(
      dismissKey: ValueKey('dismiss-${todo.id}'),
      onDismissed: () => todos.remove(todo),
      child: BrandedRow(
        onTap: () {
          HapticFeedback.selectionClick();
          todos.toggle(todo);
        },
        leading: BrandedCheckbox(checked: todo.done),
        child: BrandedText(
          todo.title,
          struck: todo.done,
          tone: todo.done ? BrandedTone.muted : BrandedTone.primary,
        ),
      ),
    );
  }
}
