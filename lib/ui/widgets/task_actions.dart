import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../data/repeat_rule.dart';
import '../../data/todo.dart';
import '../../state/providers.dart';
import '../../state/task_draft.dart';
import '../branded/branded.dart';
import '../task_editor_page.dart';
import 'month_picker_sheet.dart';

/// The things you can do to a task, reached by swiping its card. Named in
/// one place so the buttons and their labels cannot drift.
IconData doneIconFor(Todo todo) =>
    todo.done ? Icons.remove_done_rounded : Icons.check_rounded;

String doneLabelFor(Todo todo) => todo.done ? 'Not done' : 'Done';

Future<void> editTask(BuildContext context, WidgetRef ref, Todo todo) async {
  final rule = await _ruleFor(ref, todo);
  if (!context.mounted) return;

  final draft = await openBrandedPage<TaskDraft>(
    context,
    (_) => TaskEditorPage(
      heading: 'Edit task',
      anchorDay: ref.read(selectedDayProvider).epochDay,
      initialText: todo.title,
      initialDue: todo.due,
      initialRepeat: rule,
    ),
  );
  if (draft != null) await ref.read(todosProvider.notifier).apply(todo, draft);
}

/// Sends a task to a later day, chosen on the month grid. Neither the past
/// nor the day it is on can be chosen. Nothing moves if the grid is swiped
/// away.
Future<void> moveTask(BuildContext context, WidgetRef ref, Todo todo) async {
  final selected = ref.read(selectedDayProvider);
  final today = ref.read(clockProvider)().startOfDay;
  final earliest = selected.isAfter(today) ? selected : today;
  final picked = await showDayPicker(
    context,
    selected: selected,
    notBefore: earliest.addDays(1),
  );
  if (picked == null) return;
  await ref.read(todosProvider.notifier).moveToDay(todo, picked.epochDay);
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
