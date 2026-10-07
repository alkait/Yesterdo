import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../data/repeat_rule.dart';
import '../../data/todo.dart';
import '../../reminders/planned_reminder.dart';
import '../../reminders/reminder_scheduler.dart';
import '../../state/day_notice.dart';
import '../../state/providers.dart';
import '../../state/task_draft.dart';
import '../branded/branded.dart';
import '../task_editor_page.dart';
import '../task_view_page.dart';
import 'month_picker_sheet.dart';
import 'sound_picker_sheet.dart';

/// The things you can do to a task, reached by swiping its card, or on the
/// attention sheet. Named in one place so the buttons and their labels
/// cannot drift. Done has no swipe button of its own any more, the circle on
/// the card is for that, but the attention sheet still offers it.
IconData doneIconFor(Todo todo) =>
    todo.done ? Icons.remove_done_rounded : Icons.check_rounded;

String doneLabelFor(Todo todo) => todo.done ? 'Not done' : 'Done';

/// Pinning is offered where a task is read: on its own screen, and on the
/// attention sheet.
IconData pinIconFor(Todo todo) =>
    todo.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined;

String pinLabelFor(Todo todo) => todo.pinned ? 'Unpin' : 'Pin';

/// A way to say where a task went, made before the task is written.
///
/// It has to be made first. A task that leaves the day being looked at takes
/// its card with it, and the [WidgetRef] that came from that card cannot be
/// read once the card has gone. So the day and the notifier are taken while
/// the card is still there, and used afterwards.
class _DayNotice {
  _DayNotice(WidgetRef ref)
    : _here = ref.read(selectedDayProvider).epochDay,
      _notices = ref.read(dayNoticeProvider.notifier);

  final int _here;
  final DayNotices _notices;

  /// Says where the task went, unless it went nowhere: on the day being
  /// looked at there is nothing to say, since the task is right there. No
  /// [key] means nothing was written, so there is nothing to say either.
  void ifElsewhere({
    required String line,
    required int day,
    required String? key,
  }) {
    if (day == _here || key == null) return;
    _notices.raise(line: line, day: day, key: key);
  }
}

/// Adds a task from a draft, and says where it went if that is not here.
Future<void> addTaskFrom(WidgetRef ref, TaskDraft draft) async {
  final notice = _DayNotice(ref);
  final key = await ref.read(todosProvider.notifier).add(draft);
  notice.ifElsewhere(line: draft.body.firstLine, day: draft.day, key: key);
}

Future<void> editTask(BuildContext context, WidgetRef ref, Todo todo) async {
  final rule = await _ruleFor(ref, todo);
  if (!context.mounted) return;

  final draft = await openBrandedPage<TaskDraft>(
    context,
    (_) => TaskEditorPage(
      heading: 'Edit task',
      anchorDay: ref.read(selectedDayProvider).epochDay,
      initialBody: todo.body,
      initialDue: todo.due,
      initialRepeat: rule,
      initialPinned: todo.pinned,
      initialCarryOver: todo.carryOver,
      pinnable: !todo.done,
    ),
  );
  if (draft == null) return;
  final notice = _DayNotice(ref);
  final key = await ref.read(todosProvider.notifier).apply(todo, draft);
  notice.ifElsewhere(line: draft.body.firstLine, day: draft.day, key: key);
}

/// Opens a task to be read in full, on its own screen.
Future<void> openTask(BuildContext context, Todo todo) =>
    openBrandedPage<void>(context, (_) => TaskViewPage(taskKey: todo.key));

/// Sends a task to another day, chosen on the month grid: any day, past
/// or to come, but the one it is on. Nothing moves if the grid is swiped
/// away.
Future<void> moveTask(BuildContext context, WidgetRef ref, Todo todo) async {
  final selected = ref.read(selectedDayProvider);
  final picked = await showDayPicker(
    context,
    selected: selected,
    isAllowed: (date) => !date.isSameDayAs(selected),
  );
  if (picked == null) return;
  final notice = _DayNotice(ref);
  final key = await ref
      .read(todosProvider.notifier)
      .moveToDay(todo, picked.epochDay);
  notice.ifElsewhere(line: todo.firstLine, day: picked.epochDay, key: key);
}

/// Puts this task's reminder up ten seconds from now, exactly as the real
/// one would come, so the notification path can be tried without waiting.
/// A developer's tool: the button for it shows only in developer mode.
const Duration rehearsalDelay = Duration(seconds: 10);

Future<void> rehearseReminder(
  BuildContext context,
  WidgetRef ref,
  Todo todo,
) async {
  final due = todo.due;
  // The sound is asked for each time, so every one can be heard as a real
  // notification, not only in the chooser.
  final sound = await showSoundPicker(
    context,
    current: due?.sound ?? ref.read(lastSoundProvider),
  );
  if (sound == null) return;

  final scheduler = ref.read(reminderSchedulerProvider);
  if (await scheduler.permission() == ReminderPermission.notAsked) {
    await scheduler.requestPermission();
  }
  final day = ref.read(selectedDayProvider).epochDay;
  await scheduler.rehearse(
    PlannedReminder(
      day: day,
      key: todo.key,
      title: todo.firstLine,
      dueLabel: due == null ? 'Rehearsal' : due.noticeLine(day),
      fireAt: ref.read(clockProvider)().add(rehearsalDelay),
      before: 0,
      sound: sound,
    ),
  );
}

/// Deleting a repeating task asks which showings to take.
///
/// A range is offered whenever the rule has showings on that side, whether or
/// not any of them have been written down yet. To the person looking at it,
/// tomorrow's showing is already there.
Future<void> deleteTask(BuildContext context, WidgetRef ref, Todo todo) async {
  final todos = ref.read(todosProvider.notifier);
  if (!todo.repeats) return todos.removeOccurrence(todo);

  final day = ref.read(selectedDayProvider).epochDay;
  final rule = await _ruleFor(ref, todo);
  final hasEarlier = rule?.hasOccurrenceBefore(day) ?? true;
  final hasLater = rule?.hasOccurrenceAfter(day) ?? true;

  // The only showing it has left. There is nothing to choose between.
  if (!hasEarlier && !hasLater) return todos.removeSeries(todo);
  if (!context.mounted) return;

  return showBrandedSheet<void>(context, (sheetContext) {
    void choose(Future<void> Function() action) {
      Navigator.of(sheetContext).pop();
      action();
    }

    final scopes = <Widget>[
      BrandedOptionRow(
        label: 'Delete this one',
        icon: Icons.event_busy_rounded,
        tone: BrandedTone.danger,
        onTap: () => choose(() => todos.removeOccurrence(todo)),
      ),
      if (hasEarlier)
        BrandedOptionRow(
          label: 'Delete this and earlier ones',
          icon: Icons.keyboard_double_arrow_left_rounded,
          tone: BrandedTone.danger,
          onTap: () => choose(() => todos.removeUpToHere(todo)),
        ),
      if (hasLater)
        BrandedOptionRow(
          label: 'Delete this and later ones',
          icon: Icons.keyboard_double_arrow_right_rounded,
          tone: BrandedTone.danger,
          onTap: () => choose(() => todos.removeFromHere(todo)),
        ),
      BrandedOptionRow(
        label: 'Delete every one',
        icon: Icons.delete_sweep_rounded,
        tone: BrandedTone.danger,
        onTap: () => choose(() => todos.removeSeries(todo)),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandedText(
          'This task repeats',
          role: BrandedTextRole.label,
          tone: BrandedTone.muted,
          align: TextAlign.center,
        ),
        const SizedBox(height: 8),
        for (final (index, scope) in scopes.indexed) ...[
          if (index > 0) const BrandedDivider(),
          scope,
        ],
        const SizedBox(height: 8),
      ],
    );
  });
}

/// The rule behind a repeating task, read back so the editor opens on it.
Future<RepeatRule?> _ruleFor(WidgetRef ref, Todo todo) async {
  if (!todo.repeats) return null;
  final day = ref.read(selectedDayProvider).epochDay;
  final rules = await ref.read(todoStoreProvider).recurrencesFor(day);
  for (final rule in rules) {
    if (rule.id == todo.recurrenceId) return rule.rule;
  }
  return null;
}
