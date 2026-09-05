import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_labels.dart';
import '../../core/day.dart';
import '../../state/backlog.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'month_picker_sheet.dart';

/// A one-off says which day it was left on; a rule says how many days it
/// was missed on, or which day when it was only one.
String backlogDetail(BacklogEntry entry, {required DateTime now}) {
  if (entry.repeats && entry.count > 1) {
    return 'Missed on ${entry.count} earlier days';
  }
  final date = dateFromEpochDay(entry.latestDay);
  final day = now.epochDay - entry.latestDay == 1
      ? 'yesterday'
      : 'on ${shortWeekdayName(date.weekday)}, ${shortDate(date)}';
  if (entry.repeats) return 'Missed $day';
  return day == 'yesterday' ? 'Yesterday' : day.substring(3);
}

/// What to do with one entry. A one-off can be done, brought to today, sent
/// to a day in the future, or deleted. A rule's missed showings are done or
/// deleted together; the rule itself goes on.
Future<void> showBacklogEntrySheet(
  BuildContext context,
  WidgetRef ref,
  BacklogEntry entry,
) {
  final backlog = ref.read(backlogProvider.notifier);
  final now = ref.read(clockProvider)();

  return showBrandedSheet<void>(context, (sheetContext) {
    void choose(Future<void> Function() action) {
      Navigator.of(sheetContext).pop();
      action();
    }

    final options = entry.repeats
        ? <Widget>[
            BrandedOptionRow(
              label: 'Done',
              icon: Icons.check_rounded,
              onTap: () => choose(() => backlog.done(entry)),
            ),
            BrandedOptionRow(
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              tone: BrandedTone.danger,
              onTap: () => choose(() => backlog.deleteMissed(entry)),
            ),
          ]
        : <Widget>[
            BrandedOptionRow(
              label: 'Done',
              icon: Icons.check_rounded,
              onTap: () => choose(() => backlog.done(entry)),
            ),
            BrandedOptionRow(
              label: 'Bring to today',
              icon: Icons.today_rounded,
              onTap: () => choose(() => backlog.bring(entry)),
            ),
            BrandedOptionRow(
              label: 'Send to future',
              icon: Icons.event_rounded,
              onTap: () => choose(() => _sendToFuture(context, ref, entry)),
            ),
            BrandedOptionRow(
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              tone: BrandedTone.danger,
              onTap: () => choose(() => backlog.delete(entry)),
            ),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: BrandedText(
            entry.todo.firstLine,
            key: const ValueKey('backlog-entry-title'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: BrandedText(
            backlogDetail(entry, now: now),
            role: BrandedTextRole.caption,
            tone: BrandedTone.muted,
          ),
        ),
        for (final (index, option) in options.indexed) ...[
          if (index > 0) const BrandedDivider(),
          option,
        ],
        const SizedBox(height: 8),
      ],
    );
  });
}

/// Asks for a day after today on the month grid, then moves the task
/// there. Nothing moves if the grid is swiped away.
Future<void> _sendToFuture(
  BuildContext context,
  WidgetRef ref,
  BacklogEntry entry,
) async {
  final today = ref.read(clockProvider)().epochDay;
  final picked = await showDayPicker(
    context,
    selected: dateFromEpochDay(entry.latestDay),
    isAllowed: (date) => date.epochDay > today,
  );
  if (picked == null) return;
  await ref.read(backlogProvider.notifier).bring(entry, day: picked.epochDay);
}
