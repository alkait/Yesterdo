import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'todo_card.dart';
import 'todo_flight.dart';
import 'todo_tile.dart';

/// The day's tasks. Open first and draggable, checked ones settled below.
///
/// Built for one day. While that day slides out and the list has already
/// turned to the next, it keeps showing what it last showed, so the page on
/// its way out does not flash the new day's tasks.
///
/// When one card changes place in the order, checked and sinking or called
/// and rising, it flies there through a [TodoFlight] rather than jumping.
/// A drag is left to the list, which already animates the drop.
class TodoListView extends ConsumerStatefulWidget {
  const TodoListView({super.key, required this.day});

  final int day;

  @override
  ConsumerState<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends ConsumerState<TodoListView>
    with TickerProviderStateMixin {
  /// Keeps at most one row swiped open at a time.
  final _swipeGroup = BrandedSwipeGroup();

  /// One key per card, so its place on screen can be measured before the
  /// new order is laid out.
  final _tileKeys = <String, GlobalKey>{};

  List<Todo>? _shown;

  TodoFlight? _flight;

  /// Where the spacer sits in the list while a flight is on.
  int _spacerIndex = 0;

  /// The next order to arrive comes from a drag, which the list animates
  /// itself.
  bool _dragging = false;

  @override
  void dispose() {
    _swipeGroup.dispose();
    _flight?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(selectedDayProvider).epochDay;
    final live = ref.watch(todosProvider).value;
    // Judged once per build, so every card agrees on the moment.
    final now = ref.watch(clockProvider)();
    if (current == widget.day && live != null && !identical(live, _shown)) {
      _adopt(live, now: now);
    }
    final todos = _shown;

    // Null only on the very first read of a day, which lasts a frame or two.
    if (todos == null) return const SizedBox.shrink();
    if (todos.isEmpty) return const _EmptyDay();

    final flight = _flight;
    return BrandedReorderableList(
      itemCount: todos.length + (flight == null ? 0 : 1),
      onReorder: (from, to) {
        // A drop during a flight would land among indices that are about
        // to change; the list puts the card back where it was.
        if (_flight != null) return;
        _dragging = true;
        ref.read(todosProvider.notifier).reorder(from, to);
      },
      itemBuilder: (context, index) {
        if (flight == null) return _tile(todos[index], index, now: now);
        if (index == _spacerIndex) return flight.spacer();
        final todo = todos[index > _spacerIndex ? index - 1 : index];
        final tile = _tile(todo, index, now: now);
        return todo.key == flight.key ? flight.slot(tile) : tile;
      },
    );
  }

  Widget _tile(Todo todo, int index, {required DateTime now}) => TodoTile(
    // The key must be the stable one. A projected occurrence has no row
    // id, so keying on that gave every one of them the same null key and
    // the list kept only the last.
    key: _tileKeys.putIfAbsent(todo.key, GlobalKey.new),
    todo: todo,
    index: index,
    swipeGroup: _swipeGroup,
    calling: todo.isCallingOn(day: widget.day, now: now),
  );

  /// Takes the new order in, and sets a flight going if exactly one card
  /// changed place and it can be seen.
  void _adopt(List<Todo> next, {required DateTime now}) {
    final previous = _shown;
    _shown = next;
    // A flight overtaken by a newer order lands at once.
    if (_flight != null) {
      _flight!.dispose();
      _flight = null;
    }
    if (_dragging) {
      _dragging = false;
      return;
    }
    if (previous == null || MediaQuery.disableAnimationsOf(context)) return;
    final move = _singleMove(previous, next);
    if (move == null) return;

    // The old geometry is still there to read: the new order has not been
    // laid out yet.
    final box = _tileKeys[move.key]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final todo = next[move.to];
    _flight = TodoFlight(
      key: move.key,
      from: box.localToGlobal(Offset.zero) & box.size,
      card: TodoCard(
        todo: todo,
        calling: todo.isCallingOn(day: widget.day, now: now),
      ),
      vsync: this,
    );
    // Whatever stood before the card still does, so the spacer goes where
    // the card was, counted in the new order.
    _spacerIndex = move.from < move.to ? move.from : move.from + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _flight == null) return;
      if (!_flight!.launch(Overlay.of(context), _land)) _land();
    });
  }

  void _land() {
    if (_flight == null) return;
    _flight!.dispose();
    if (mounted) setState(() => _flight = null);
  }

  /// The one card whose place changed, if taking it out of both orders
  /// leaves them the same. Null for any other kind of change.
  static ({String key, int from, int to})? _singleMove(
    List<Todo> previous,
    List<Todo> next,
  ) {
    if (previous.length != next.length) return null;
    final before = [for (final todo in previous) todo.key];
    final after = [for (final todo in next) todo.key];
    for (var at = 0; at < before.length; at++) {
      if (before[at] == after[at]) continue;
      for (final key in [before[at], after[at]]) {
        final to = after.indexOf(key);
        final from = before.indexOf(key);
        // A key on one side only is a task replaced, not moved.
        if (to == -1 || from == -1) continue;
        final restBefore = [...before]..removeAt(from);
        final restAfter = [...after]..removeAt(to);
        if (_sameOrder(restBefore, restAfter)) {
          return (key: key, from: from, to: to);
        }
      }
      return null;
    }
    return null;
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    for (var at = 0; at < a.length; at++) {
      if (a[at] != b[at]) return false;
    }
    return true;
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
