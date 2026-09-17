import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/backlog.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'task_view_page.dart';
import 'widgets/backlog_entry_sheet.dart';
import 'widgets/day_notice_banner.dart';

/// What was left undone on earlier days, on a screen of its own. A one-off
/// is a card of its own; a rule's missed showings are one card with a
/// count, done or deleted together. Tapping a card asks what to do with it,
/// and swiping it left uncovers View, which opens the words in full. A task
/// sent on to a day is announced by the banner at the foot, which offers to
/// go to it. The screen never leaves on its own, even once nothing is left:
/// it is left by Back, or by the banner's Go, so the rest can be seen to
/// first.
class BacklogPage extends ConsumerStatefulWidget {
  const BacklogPage({super.key});

  @override
  ConsumerState<BacklogPage> createState() => _BacklogPageState();
}

class _BacklogPageState extends ConsumerState<BacklogPage> {
  /// Keeps at most one card swiped open at a time.
  final _swipeGroup = BrandedSwipeGroup();

  @override
  void dispose() {
    _swipeGroup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Stack(
            children: [
              // The same list the day uses, so a swipe on a card here feels
              // the same as one there. Nothing is lifted: there is no drag
              // lift.
              if (backlog.isEmpty)
                const Center(
                  child: BrandedText(
                    'Nothing left behind',
                    role: BrandedTextRole.label,
                    tone: BrandedTone.muted,
                  ),
                )
              else
                BrandedReorderableList(
                  itemCount: backlog.entries.length,
                  onReorder: (_, _) {},
                  itemBuilder: (context, index) {
                    final entry = backlog.entries[index];
                    return BrandedSwipeActions(
                      key: ValueKey('backlog-swipe-${entry.key}'),
                      group: _swipeGroup,
                      id: entry.key,
                      trailing: [
                        BrandedSwipeAction(
                          icon: Icons.visibility_outlined,
                          label: 'View',
                          onTap: () => openBrandedPage<void>(
                            context,
                            (_) => TaskViewPage.of(
                              entry.todo,
                              day: entry.latestDay,
                            ),
                          ),
                        ),
                      ],
                      child: _EntryCard(
                        entry: entry,
                        detail: backlogDetail(entry, now: now),
                        onTap: () => showBacklogEntrySheet(context, ref, entry),
                      ),
                    );
                  },
                ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DayNoticeBanner(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.detail,
    required this.onTap,
  });

  final BacklogEntry entry;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BrandedCard(
    key: ValueKey('backlog-${entry.key}'),
    onTap: onTap,
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
                detail,
                role: BrandedTextRole.caption,
                tone: BrandedTone.muted,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
