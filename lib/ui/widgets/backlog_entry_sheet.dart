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
/// to a day in the future, or deleted. A rule's missed showings are done,
/// ignored or deleted together; the rule itself goes on. Either kind can be
/// gone to and left where it is. A task sent on is announced by the banner,
/// which offers to go to it.
Future<void> showBacklogEntrySheet(
  BuildContext context,
  WidgetRef ref,
  BacklogEntry entry,
) {
  final backlog = ref.read(backlogProvider.notifier);
  final days = ref.read(selectedDayProvider.notifier);
  final now = ref.read(clockProvider)();

  final spotlights = ref.read(spotlightProvider.notifier);

  /// Turns the list to the day the entry was left on, and comes back out to
  /// it, with the card pointed out there. A rule missed more than once goes
  /// to the last of them. Nothing is changed: this is a way of going to
  /// look.
  void goToDay() {
    spotlights.raise(entry.latestDay, entry.key);
    days.select(dateFromEpochDay(entry.latestDay));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  return showBrandedSheet<void>(context, (sheetContext) {
    void choose(Future<void> Function() action) {
      Navigator.of(sheetContext).pop();
      action();
    }

    final goRow = BrandedOptionRow(
      key: const ValueKey('backlog-go-to-day'),
      label: 'Go to day',
      detail: entry.repeats && entry.count > 1
          ? 'The last day it was missed on'
          : null,
      icon: Icons.arrow_outward_rounded,
      onTap: () => choose(() async => goToDay()),
    );

    final options = entry.repeats
        ? <Widget>[
            BrandedOptionRow(
              label: 'Done',
              icon: Icons.check_rounded,
              onTap: () => choose(() => backlog.done(entry)),
            ),
            goRow,
            BrandedOptionRow(
              label: 'Ignore',
              icon: Icons.visibility_off_outlined,
              onTap: () => choose(() => backlog.ignoreMissed(entry)),
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
            goRow,
            BrandedOptionRow(
              label: 'Bring to today',
              icon: Icons.today_rounded,
              onTap: () => choose(() => _sendOn(ref, entry, now.epochDay)),
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
  await _sendOn(ref, entry, picked.epochDay);
}

/// Moves the task to [day] and says so through the banner, which offers to
/// go to it. The list is not turned: the screen stays, so the rest can be
/// seen to, and the banner is the way there. The notifiers are taken first,
/// since the sheet this was chosen on is down before the move lands.
Future<void> _sendOn(WidgetRef ref, BacklogEntry entry, int day) async {
  final backlog = ref.read(backlogProvider.notifier);
  final notices = ref.read(dayNoticeProvider.notifier);
  final key = await backlog.bring(entry, day: day);
  notices.raise(line: entry.todo.firstLine, day: day, key: key);
}
