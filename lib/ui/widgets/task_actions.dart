import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../data/repeat_rule.dart';
import '../../data/todo.dart';
import '../../state/providers.dart';
import '../../state/task_draft.dart';
import '../branded/branded.dart';
import '../task_editor_page.dart';

/// The three things you can do to a task, named in one place so the swipe
/// buttons and the sheet can never drift apart.
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
      initialRepeat: rule,
    ),
  );
  if (draft != null) await ref.read(todosProvider.notifier).apply(todo, draft);
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

/// Everything you can do to one task, reached by double tapping it.
Future<void> showTaskActions(BuildContext context, WidgetRef ref, Todo todo) {
  final todos = ref.read(todosProvider.notifier);

  return showBrandedSheet<void>(context, (sheetContext) {
    void close() => Navigator.of(sheetContext).pop();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandedText(
          todo.firstLine,
          role: BrandedTextRole.label,
          tone: BrandedTone.muted,
          align: TextAlign.center,
          maxLines: 1,
        ),
        const SizedBox(height: 16),
        BrandedActionGrid(
          children: [
            BrandedActionButton(
              icon: doneIconFor(todo),
              label: doneLabelFor(todo),
              onTap: () {
                close();
                todos.toggle(todo);
              },
            ),
            BrandedActionButton(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () {
                close();
                editTask(context, ref, todo);
              },
            ),
            BrandedActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              tone: BrandedTone.danger,
              onTap: () {
                close();
                deleteTask(context, ref, todo);
              },
            ),
          ],
        ),
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
