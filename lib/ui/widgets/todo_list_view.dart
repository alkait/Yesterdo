import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'todo_tile.dart';

/// The day's tasks. Open first and draggable, checked ones settled below.
///
/// Built for one day. While that day slides out and the list has already
/// turned to the next, it keeps showing what it last showed, so the page on
/// its way out does not flash the new day's tasks.
class TodoListView extends ConsumerStatefulWidget {
  const TodoListView({super.key, required this.day});

  final int day;

  @override
  ConsumerState<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends ConsumerState<TodoListView> {
  /// Keeps at most one row swiped open at a time.
  final _swipeGroup = BrandedSwipeGroup();

  List<Todo>? _shown;

  @override
  void dispose() {
    _swipeGroup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(selectedDayProvider).epochDay;
    final live = ref.watch(todosProvider).value;
    if (current == widget.day && live != null) _shown = live;
    final todos = _shown;
    // Judged once per build, so every card agrees on the moment.
    final now = ref.watch(clockProvider)();

    // Null only on the very first read of a day, which lasts a frame or two.
    if (todos == null) return const SizedBox.shrink();
    if (todos.isEmpty) return const _EmptyDay();

    return BrandedReorderableList(
      itemCount: todos.length,
      onReorder: ref.read(todosProvider.notifier).reorder,
      itemBuilder: (context, index) {
        final todo = todos[index];
        // The key must be the stable one. A projected occurrence has no row
        // id, so keying on that gave every one of them the same null key and
        // the list kept only the last.
        return TodoTile(
          key: ValueKey(todo.key),
          todo: todo,
          index: index,
          swipeGroup: _swipeGroup,
          calling: todo.isCallingOn(day: widget.day, now: now),
        );
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
