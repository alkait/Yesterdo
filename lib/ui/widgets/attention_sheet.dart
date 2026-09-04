import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/due.dart';
import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'task_actions.dart';

/// The sheet a calling task puts up, from a tap on its card or on its
/// notification. It opens with the task's words in full, so the context is
/// clear however it was reached, and offers done, snooze and dismiss.
Future<void> showAttentionSheet(
  BuildContext context,
  WidgetRef ref,
  Todo todo,
) {
  final todos = ref.read(todosProvider.notifier);
  final twentyFourHour = MediaQuery.alwaysUse24HourFormatOf(context);

  return showBrandedSheet<void>(context, (sheetContext) {
    void choose(Future<void> Function() action) {
      Navigator.of(sheetContext).pop();
      action();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: BrandedText(
            todo.title,
            key: const ValueKey('attention-title'),
          ),
        ),
        // The time can have been cleared between a notification firing and
        // its tap, in which case the words alone are the context.
        if (todo.due case final due?)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: BrandedText(
              'Due ${due.label(twentyFourHour: twentyFourHour)}',
              role: BrandedTextRole.caption,
              tone: BrandedTone.accent,
            ),
          )
        else
          const SizedBox(height: 8),
        BrandedOptionRow(
          label: doneLabelFor(todo),
          icon: doneIconFor(todo),
          onTap: () => choose(() => todos.toggle(todo)),
        ),
        const BrandedDivider(),
        BrandedOptionRow(
          label: 'Snooze',
          detail: '${Due.snoozeStep} minutes',
          icon: Icons.snooze_rounded,
          onTap: () => choose(() => todos.snooze(todo)),
        ),
        const BrandedDivider(),
        BrandedOptionRow(
          label: 'Not today',
          icon: Icons.event_rounded,
          onTap: () => choose(() => moveTask(context, ref, todo)),
        ),
        const BrandedDivider(),
        BrandedOptionRow(
          label: 'Dismiss',
          icon: Icons.notifications_off_outlined,
          onTap: () => choose(() => todos.dismiss(todo)),
        ),
        const SizedBox(height: 8),
      ],
    );
  });
}
