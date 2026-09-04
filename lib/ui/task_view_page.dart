import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rich/task_body.dart';
import '../data/todo.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'widgets/task_actions.dart';

/// A task read in full: its words with their styles, its checklist with
/// boxes that tick, its links that open. Reached by tapping a card. Edit
/// leads on to the editor.
class TaskViewPage extends ConsumerWidget {
  const TaskViewPage({super.key, required this.taskKey});

  /// The task's [Todo.key], looked up afresh on every build so a tick
  /// shows at once.
  final String taskKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(todosProvider).value ?? const <Todo>[];
    final todo = todos.where((each) => each.key == taskKey).firstOrNull;
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
          trailing: BrandedTextButton(
            label: 'Edit',
            onTap: () => editTask(context, ref, todo),
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
                for (final (index, block) in todo.body.blocks.indexed)
                  _BlockView(
                    block: block,
                    struck: todo.done,
                    onTick: block.isCheck
                        ? () => ref
                              .read(todosProvider.notifier)
                              .setBody(todo, todo.body.toggled(index))
                        : null,
                    onLink: ref.read(deviceBridgeProvider).openUrl,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: Brand.gap),
          child: BrandedCheckBox(
            key: ValueKey('tick-${block.text}'),
            checked: block.checked,
            onTap: onTick,
          ),
        ),
        Expanded(child: words),
      ],
    );
  }
}
