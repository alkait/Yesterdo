import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import '../task_editor_page.dart';

/// The three things you can do to a task, named in one place so the swipe
/// buttons and the sheet can never drift apart.
IconData doneIconFor(Todo todo) =>
    todo.done ? Icons.remove_done_rounded : Icons.check_rounded;

String doneLabelFor(Todo todo) => todo.done ? 'Not done' : 'Done';

Future<void> editTask(BuildContext context, WidgetRef ref, Todo todo) async {
  final title = await openBrandedPage<String>(
    context,
    (_) => TaskEditorPage(heading: 'Edit task', initialText: todo.title),
  );
  if (title != null) await ref.read(todosProvider.notifier).rename(todo, title);
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
                todos.remove(todo);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  });
}
