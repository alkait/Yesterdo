import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rich/task_body.dart';
import '../core/day.dart';
import '../data/todo.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'image_view_page.dart';
import 'repeat_history_page.dart';
import 'widgets/task_actions.dart';
import 'widgets/todo_flight.dart';

/// A task read in full: its words with their styles, its checklist with
/// boxes that tick, a ticked item flying to the foot of its list, and open
/// items that lift, on a press and hold, to be put in a new order among
/// themselves; its links that open. Reached by tapping
/// a card. Edit leads on to the editor, and Share hands the words alone to
/// another app.
///
/// Given a task outright, through [TaskViewPage.of], it shows that one as
/// it stands: a task left on an earlier day, looked at from the backlog.
/// It is only read there: no Edit, the boxes do not tick and nothing lifts.
class TaskViewPage extends ConsumerWidget {
  const TaskViewPage({super.key, required this.taskKey})
    : given = null,
      givenDay = null;

  const TaskViewPage.of(Todo todo, {super.key, required int day})
    : taskKey = '',
      given = todo,
      givenDay = day;

  /// The task's [Todo.key], looked up afresh on every build so a tick
  /// shows at once.
  final String taskKey;

  final Todo? given;

  /// The day [given] stands on, where its rule is read from.
  final int? givenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(todosProvider).value ?? const <Todo>[];
    final todo =
        given ?? todos.where((each) => each.key == taskKey).firstOrNull;
    if (todo == null) {
      // Gone, deleted from under the view; nothing to show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const BrandedScaffold(children: []);
    }

    return BrandedScaffold(
      children: [
        BrandedAppBar(
          leading: BrandedTextButton(
            label: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          center: const BrandedText(
            'Task',
            role: BrandedTextRole.title,
            align: TextAlign.center,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandedIconButton(
                icon: Icons.ios_share,
                label: 'Share',
                size: BrandedIconSize.medium,
                onTap: () =>
                    ref.read(deviceBridgeProvider).share(todo.body.shareText),
              ),
              if (given == null)
                BrandedTextButton(
                  label: 'Edit',
                  onTap: () => editTask(context, ref, todo),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Brand.gutter,
              vertical: Brand.gap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final piece in _pieces(todo.body))
                  switch (piece) {
                    _Picture(:final image) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: BrandedImage(
                        key: ValueKey('picture-$image'),
                        path: '${ref.watch(imagesDirectoryProvider)}/$image',
                        onTap: () => openBrandedPage<void>(
                          context,
                          (_) => ImageViewPage(
                            path: '${ref.read(imagesDirectoryProvider)}/$image',
                          ),
                        ),
                      ),
                    ),
                    _Words(:final index) => _blockView(ref, todo, index),
                    _Checklist(:final start, :final length) => _ChecklistRun(
                      key: ValueKey('checklist-$start'),
                      ids: _idsFor(todo.body, start, length),
                      items: [
                        for (var at = start; at < start + length; at++)
                          _blockView(ref, todo, at),
                      ],
                      lifts: [
                        for (var at = start; at < start + length; at++)
                          !todo.body.blocks[at].checked,
                      ],
                      // Items move only among their own list, so a drop is
                      // counted from where the list begins in the body.
                      onReorder: given == null
                          ? (from, to) => ref
                                .read(todosProvider.notifier)
                                .setBody(
                                  todo,
                                  todo.body.reordered(start + from, start + to),
                                )
                          : null,
                    ),
                  },
                if (todo.due != null || todo.repeats)
                  _Particulars(
                    todo: todo,
                    day: givenDay ?? ref.watch(selectedDayProvider).epochDay,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blockView(WidgetRef ref, Todo todo, int index) {
    final block = todo.body.blocks[index];
    return _BlockView(
      key: ValueKey('block-$index'),
      block: block,
      struck: todo.done,
      onTick: block.isCheck && given == null
          ? () => ref.read(todosProvider.notifier).tick(todo, index)
          : null,
      onLink: ref.read(deviceBridgeProvider).openUrl,
    );
  }

  /// What tells the items of a run apart from one build to the next, so a
  /// move can be seen: the words, and a count for words that repeat. The
  /// words stay the same through a tick, so a ticked item keeps its name
  /// on its way to the foot.
  static List<String> _idsFor(TaskBody body, int start, int length) {
    final seen = <String, int>{};
    return [
      for (var at = start; at < start + length; at++)
        '${body.blocks[at].text}#'
            '${seen[body.blocks[at].text] = (seen[body.blocks[at].text] ?? -1) + 1}',
    ];
  }

  /// The body cut into what is drawn: a picture, a paragraph, or a run of
  /// checklist items standing together, which is the list they can be
  /// reordered within.
  static List<_Piece> _pieces(TaskBody body) {
    final pieces = <_Piece>[];
    var at = 0;
    while (at < body.blocks.length) {
      final block = body.blocks[at];
      if (block.image case final image?) {
        pieces.add(_Picture(image));
        at++;
      } else if (!block.isCheck) {
        pieces.add(_Words(at));
        at++;
      } else {
        final start = at;
        while (at < body.blocks.length && body.blocks[at].isCheck) {
          at++;
        }
        pieces.add(_Checklist(start, at - start));
      }
    }
    return pieces;
  }
}

sealed class _Piece {
  const _Piece();
}

class _Picture extends _Piece {
  const _Picture(this.image);
  final String image;
}

class _Words extends _Piece {
  const _Words(this.index);
  final int index;
}

class _Checklist extends _Piece {
  const _Checklist(this.start, this.length);
  final int start;
  final int length;
}

/// A run of checklist items. The open ones lift on a press and hold to be
/// dragged into a new place among themselves; ticked ones hold the foot of
/// the list, so a drop among them is put back above. Without [onReorder]
/// nothing lifts.
///
/// When one item changes place, ticked and sinking or unticked and rising,
/// it flies there through a [TodoFlight] rather than jumping, as a card on
/// the day does. A drag is left to the list, which animates the drop.
class _ChecklistRun extends StatefulWidget {
  const _ChecklistRun({
    super.key,
    required this.ids,
    required this.items,
    required this.lifts,
    required this.onReorder,
  });

  /// One name per item, stable through a tick, so a move can be seen.
  final List<String> ids;

  final List<Widget> items;

  /// Which items may be lifted: the open ones.
  final List<bool> lifts;

  final void Function(int from, int to)? onReorder;

  @override
  State<_ChecklistRun> createState() => _ChecklistRunState();
}

class _ChecklistRunState extends State<_ChecklistRun>
    with TickerProviderStateMixin {
  /// One key per item, so its place on screen can be measured before the
  /// new order is laid out.
  final _itemKeys = <String, GlobalKey>{};

  TodoFlight? _flight;

  /// Where the spacer sits in the list while a flight is on.
  int _spacerIndex = 0;

  /// The next order to arrive comes from a drag, which the list animates
  /// itself.
  bool _dragging = false;

  @override
  void didUpdateWidget(_ChecklistRun old) {
    super.didUpdateWidget(old);
    _adopt(old.ids, widget.ids);
  }

  @override
  void dispose() {
    _flight?.dispose();
    super.dispose();
  }

  /// A drop lands no lower than the last open item.
  void _drop(int from, int to) {
    if (_flight != null) return;
    final open = widget.lifts.where((lifts) => lifts).length;
    final target = to.clamp(0, open - 1);
    if (target == from) return;
    _dragging = true;
    widget.onReorder!(from, target);
  }

  /// Sets a flight going if exactly one item changed place and it can be
  /// seen. The old geometry is still there to read: the new order has not
  /// been laid out yet.
  void _adopt(List<String> previous, List<String> next) {
    // A flight overtaken by a newer order lands at once.
    if (_flight != null) {
      _flight!.dispose();
      _flight = null;
    }
    if (_dragging) {
      _dragging = false;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) return;
    final move = singleMove(previous, next);
    if (move == null) return;
    final box = _itemKeys[move.key]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _flight = TodoFlight(
      key: move.key,
      from: box.localToGlobal(Offset.zero) & box.size,
      card: widget.items[move.to],
      vsync: this,
    );
    // Whatever stood before the item still does, so the spacer goes where
    // the item was, counted in the new order.
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

  @override
  Widget build(BuildContext context) {
    final flight = _flight;
    return BrandedReorderableList(
      embedded: true,
      itemCount: widget.ids.length + (flight == null ? 0 : 1),
      onReorder: widget.onReorder == null ? (_, _) {} : _drop,
      itemBuilder: (context, index) {
        if (flight == null) return _item(index);
        if (index == _spacerIndex) return flight.spacer();
        final at = index > _spacerIndex ? index - 1 : index;
        final item = _item(at);
        return widget.ids[at] == flight.key ? flight.slot(item) : item;
      },
    );
  }

  Widget _item(int index) {
    final id = widget.ids[index];
    final child = KeyedSubtree(
      key: _itemKeys.putIfAbsent(id, GlobalKey.new),
      child: widget.items[index],
    );
    if (widget.onReorder == null || !widget.lifts[index]) {
      return KeyedSubtree(key: ValueKey('item-$id'), child: child);
    }
    return BrandedDragLift(
      key: ValueKey('item-$id'),
      index: index,
      child: child,
    );
  }
}

/// The time, the reminder and the repeat, under the words, read only: the
/// same rows the editor has, without the chevrons. Only what is set is shown. A
/// repeating task has a History row too, the one row here that leads on,
/// which says how many showings were done and opens them day by day.
class _Particulars extends ConsumerWidget {
  const _Particulars({required this.todo, required this.day});

  final Todo todo;
  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twentyFourHour = MediaQuery.alwaysUse24HourFormatOf(context);
    final rule = todo.repeats
        ? ref
              .watch(
                ruleForProvider((day: day, recurrenceId: todo.recurrenceId)),
              )
              .value
        : null;
    final history = todo.repeats
        ? ref.watch(repeatHistoryProvider(todo.recurrenceId!)).value
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: Brand.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandedDivider(),
          if (todo.due case final due?) ...[
            BrandedFieldRow(
              label: 'Time',
              icon: Icons.schedule_outlined,
              value: due.label(twentyFourHour: twentyFourHour),
            ),
            if (due.hasReminder) ...[
              const BrandedDivider(),
              BrandedFieldRow(
                label: 'Reminder',
                icon: Icons.notifications_none_rounded,
                value: due.remindersLabel(twentyFourHour: twentyFourHour),
              ),
            ],
            if (todo.repeats) const BrandedDivider(),
          ],
          if (todo.repeats) ...[
            BrandedFieldRow(
              label: 'Repeat',
              icon: Icons.repeat_rounded,
              // The rule arrives a moment after the words.
              value: rule?.label ?? '',
              detail: rule?.detail,
            ),
            const BrandedDivider(),
            BrandedFieldRow(
              key: const ValueKey('history-row'),
              label: 'History',
              icon: Icons.history_rounded,
              value: history?.summary ?? '',
              // Nothing to walk through until the first showing has come.
              onTap: history == null || history.isEmpty
                  ? null
                  : () => openBrandedPage<void>(
                      context,
                      (_) => RepeatHistoryPage(todo: todo),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({
    super.key,
    required this.block,
    required this.struck,
    required this.onTick,
    required this.onLink,
  });

  final Block block;
  final bool struck;
  final VoidCallback? onTick;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) {
    final ticked = block.isCheck && block.checked;
    final words = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: BrandedRichText(
        block.content,
        struck: struck || ticked,
        tone: struck || ticked ? BrandedTone.muted : BrandedTone.primary,
        onLink: onLink,
      ),
    );
    if (!block.isCheck) return words;
    // The whole line ticks, not just the box, and the box sits on the side
    // the words start from. A link in the words still wins, as the nearer
    // gesture.
    return Directionality(
      textDirection: brandedTextDirection(block.text),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTick,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Brand.gap / 2),
              child: BrandedCheckBox(
                key: ValueKey('tick-${block.text}'),
                checked: block.checked,
                onTap: onTick,
              ),
            ),
            Expanded(child: words),
          ],
        ),
      ),
    );
  }
}
