import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rich/task_body.dart';
import '../core/day.dart';
import '../data/todo.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'image_view_page.dart';
import 'widgets/task_actions.dart';

/// A task read in full: its words with their styles, its checklist with
/// boxes that tick, its links that open. Reached by tapping a card. Edit
/// leads on to the editor.
///
/// Given a task outright, through [TaskViewPage.of], it shows that one as
/// it stands: a task left on an earlier day, looked at from the backlog.
/// It is only read there: no Edit, and the boxes do not tick.
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
          trailing: given == null
              ? BrandedTextButton(
                  label: 'Edit',
                  onTap: () => editTask(context, ref, todo),
                )
              : null,
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
                  if (block.image case final image?)
                    Padding(
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
                    )
                  else
                    _BlockView(
                      block: block,
                      struck: todo.done,
                      onTick: block.isCheck && given == null
                          ? () => ref
                                .read(todosProvider.notifier)
                                .setBody(todo, todo.body.toggled(index))
                          : null,
                      onLink: ref.read(deviceBridgeProvider).openUrl,
                    ),
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
}

/// The due time and the repeat, under the words, read only: the same rows
/// the editor has, without the chevrons. Only what is set is shown.
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
    return Padding(
      padding: const EdgeInsets.only(top: Brand.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandedDivider(),
          if (todo.due case final due?) ...[
            BrandedFieldRow(
              label: 'Due',
              value: due.label(twentyFourHour: twentyFourHour),
              detail: due.hasReminder
                  ? due.remindersLabel(twentyFourHour: twentyFourHour)
                  : null,
            ),
            if (todo.repeats) const BrandedDivider(),
          ],
          if (todo.repeats)
            BrandedFieldRow(
              label: 'Repeat',
              // The rule arrives a moment after the words.
              value: rule?.label ?? '',
              detail: rule?.detail,
            ),
        ],
      ),
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
