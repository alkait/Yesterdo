import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_labels.dart';
import '../core/day.dart';
import '../data/todo.dart';
import '../state/providers.dart';
import '../state/repeat_history.dart';
import 'branded/branded.dart';

/// How a repeating task has gone, on a screen of its own: the words, how
/// many of its showings were done, then every day it fell on, newest first
/// and grouped by month, each saying whether it was done or missed. Only
/// read: nothing here is tapped.
class RepeatHistoryPage extends ConsumerWidget {
  const RepeatHistoryPage({super.key, required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(repeatHistoryProvider(todo.recurrenceId!)).value ??
        RepeatHistory.empty;
    final today = ref.watch(clockProvider)().epochDay;

    return BrandedScaffold(
      children: [
        BrandedAppBar(
          leading: BrandedTextButton(
            label: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          center: const BrandedText(
            'History',
            role: BrandedTextRole.title,
            align: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: Brand.gutter,
              vertical: Brand.gap,
            ),
            children: [
              BrandedText(todo.firstLine, role: BrandedTextRole.card),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BrandedText(
                  history.summary,
                  key: const ValueKey('history-summary'),
                  role: BrandedTextRole.title,
                ),
              ),
              for (final (index, entry) in history.entries.indexed) ...[
                if (index == 0 ||
                    !_sameMonth(entry.day, history.entries[index - 1].day))
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Brand.gap * 2,
                      bottom: 4,
                    ),
                    child: BrandedText(
                      monthAndYear(dateFromEpochDay(entry.day)),
                      role: BrandedTextRole.caption,
                      tone: BrandedTone.muted,
                    ),
                  )
                else
                  const BrandedDivider(),
                _HistoryRow(entry: entry, today: today),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static bool _sameMonth(int a, int b) {
    final first = dateFromEpochDay(a);
    final second = dateFromEpochDay(b);
    return first.year == second.year && first.month == second.month;
  }
}

/// One showing: the day on the left, how it went on the right. Done reads
/// in the primary tone with a check; missed and open are muted.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.today});

  final HistoryEntry entry;
  final int today;

  @override
  Widget build(BuildContext context) {
    final tone = entry.outcome.isDone ? BrandedTone.primary : BrandedTone.muted;
    return Semantics(
      label: '${_dayLabel()}, ${entry.outcome.label}',
      child: Container(
        key: ValueKey('history-${entry.day}'),
        constraints: const BoxConstraints(minHeight: Brand.rowMinHeight),
        padding: const EdgeInsets.symmetric(vertical: Brand.rowPadding),
        child: Row(
          children: [
            Expanded(child: BrandedText(_dayLabel(), maxLines: 1)),
            const SizedBox(width: Brand.gap),
            BrandedText(entry.outcome.label, tone: tone),
            const SizedBox(width: Brand.gap / 2),
            BrandedIcon(
              switch (entry.outcome) {
                HistoryOutcome.done => Icons.check_rounded,
                HistoryOutcome.missed => Icons.remove_rounded,
                HistoryOutcome.open => Icons.radio_button_unchecked_rounded,
              },
              size: BrandedIconSize.medium,
              tone: tone,
            ),
          ],
        ),
      ),
    );
  }

  /// `Today`, `Yesterday`, else `Thu, Sep 3`.
  String _dayLabel() {
    final date = dateFromEpochDay(entry.day);
    return switch (today - entry.day) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => '${shortWeekdayName(date.weekday)}, ${shortDate(date)}',
    };
  }
}
