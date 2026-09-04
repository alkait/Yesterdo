import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../state/providers.dart';
import '../../state/task_draft.dart';
import '../branded/branded.dart';
import '../task_editor_page.dart';

/// The bar pinned to the bottom. It opens the editor rather than taking text
/// inline, so writing a task always happens on its own screen.
class AddTaskBar extends ConsumerWidget {
  const AddTaskBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => BrandedBottomBar(
    onTap: () => _add(context, ref),
    child: const Row(
      children: [
        BrandedIcon(Icons.add_rounded),
        SizedBox(width: 12),
        BrandedText('Add a task', tone: BrandedTone.muted),
      ],
    ),
  );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await openBrandedPage<TaskDraft>(
      context,
      (_) => TaskEditorPage(
        heading: 'New task',
        anchorDay: ref.read(selectedDayProvider).epochDay,
      ),
    );
    if (draft != null) await ref.read(todosProvider.notifier).add(draft);
  }
}
