import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/backlog.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'widgets/backlog_entry_sheet.dart';

/// What was left undone on earlier days, on a screen of its own. A one-off
/// is a card of its own; a rule's missed showings are one card with a
/// count. Tapping a card asks what to do with it, and the screen goes back
/// by itself once nothing is left.
class BacklogPage extends ConsumerWidget {
  const BacklogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(backlogProvider, (_, next) {
      if (next.value?.isEmpty ?? false) Navigator.of(context).pop();
    });
    final backlog = ref.watch(backlogProvider).value ?? Backlog.empty;
    final now = ref.watch(clockProvider)();

    return BrandedScaffold(
      children: [
        BrandedAppBar(
          leading: BrandedTextButton(
            label: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          center: const BrandedText(
            'Left behind',
            role: BrandedTextRole.title,
            align: TextAlign.center,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: Brand.cardGap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in backlog.entries)
                  BrandedCard(
                    key: ValueKey('backlog-${entry.key}'),
                    onTap: () => showBacklogEntrySheet(context, ref, entry),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BrandedText(
                          entry.todo.firstLine,
                          role: BrandedTextRole.card,
                          maxLines: Brand.cardLines,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (entry.repeats) ...[
                                const BrandedIcon(
                                  Icons.repeat_rounded,
                                  size: BrandedIconSize.small,
                                  tone: BrandedTone.muted,
                                ),
                                const SizedBox(width: 4),
                              ],
                              BrandedText(
                                backlogDetail(entry, now: now),
                                role: BrandedTextRole.caption,
                                tone: BrandedTone.muted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
