import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/todo.dart';
import '../../state/providers.dart';
import '../../state/todos_controller.dart';
import '../branded/branded.dart';
import '../task_editor_page.dart';

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
              icon: todo.done ? Icons.remove_done_rounded : Icons.check_rounded,
              label: todo.done ? 'Not done' : 'Done',
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
                _edit(context, todos, todo);
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

Future<void> _edit(
  BuildContext context,
  TodosController todos,
  Todo todo,
) async {
  final title = await openBrandedPage<String>(
    context,
    (_) => TaskEditorPage(heading: 'Edit task', initialText: todo.title),
  );
  if (title != null) await todos.rename(todo, title);
}
