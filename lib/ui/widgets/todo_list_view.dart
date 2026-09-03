import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../branded/branded.dart';
import 'todo_tile.dart';

/// The day's tasks. Open first, checked ones settled at the bottom.
class TodoListView extends ConsumerWidget {
  const TodoListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(todosProvider).value;

    // Null only on the very first read of a day, which lasts a frame or two.
    if (todos == null) return const SizedBox.shrink();
    if (todos.isEmpty) return const _EmptyDay();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return TodoTile(key: ValueKey(todo.id), todo: todo);
      },
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) => const Center(
    child: BrandedText(
      'Nothing planned',
      role: BrandedTextRole.label,
      tone: BrandedTone.muted,
    ),
  );
}
