import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_labels.dart';
import '../../core/day.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// Turns the list to a day picked from the month grid.
Future<void> showMonthPickerSheet(BuildContext context, WidgetRef ref) {
  final selected = ref.read(selectedDayProvider);
  return showBrandedSheet<void>(
    context,
    (sheetContext) => _MonthPicker(
      selected: selected,
      onPick: (date) {
        ref.read(selectedDayProvider.notifier).select(date);
        Navigator.of(sheetContext).pop();
      },
    ),
  );
}

/// Asks for a day on or after [notBefore], marking [selected] as where the
/// task is now. Days before that, [selected] itself included, are greyed and
/// ignore the finger. Returns the day, or null when the sheet is swiped
/// away.
Future<DateTime?> showDayPicker(
  BuildContext context, {
  required DateTime selected,
  required DateTime notBefore,
}) => showBrandedSheet<DateTime>(
  context,
  (sheetContext) => _MonthPicker(
    selected: selected,
    notBefore: notBefore,
    onPick: (date) => Navigator.of(sheetContext).pop(date),
  ),
);

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({
    required this.selected,
    required this.onPick,
    this.notBefore,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  /// The first day that can be picked, or null for any day at all.
  final DateTime? notBefore;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  void _stepMonth(int amount) =>
      setState(() => _month = DateTime(_month.year, _month.month + amount));

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _MonthBar(
        label: monthAndYear(_month),
        onPrevious: () => _stepMonth(-1),
        onNext: () => _stepMonth(1),
      ),
      const SizedBox(height: 4),
      const _WeekdayStrip(),
      const SizedBox(height: 4),
      _DayGrid(
        month: _month,
        selected: widget.selected,
        notBefore: widget.notBefore,
        onPick: widget.onPick,
      ),
      const SizedBox(height: 8),
      // Only a free choice has a shortcut to today; a constrained one may
      // not allow it.
      if (widget.notBefore == null)
        BrandedTextButton(
          label: 'Today',
          onTap: () => widget.onPick(todayDate()),
        ),
    ],
  );
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      BrandedIconButton(
        icon: Icons.chevron_left_rounded,
        label: 'Previous month',
        onTap: onPrevious,
        size: BrandedIconSize.medium,
      ),
      Expanded(
        child: BrandedText(
          label,
          role: BrandedTextRole.title,
          align: TextAlign.center,
        ),
      ),
      BrandedIconButton(
        icon: Icons.chevron_right_rounded,
        label: 'Next month',
        onTap: onNext,
        size: BrandedIconSize.medium,
      ),
    ],
  );
}

class _WeekdayStrip extends StatelessWidget {
  const _WeekdayStrip();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, initial) in weekdayInitials.indexed)
        Expanded(
          key: ValueKey('weekday-$index'),
          child: BrandedText(
            initial,
            role: BrandedTextRole.caption,
            tone: BrandedTone.muted,
            align: TextAlign.center,
          ),
        ),
    ],
  );
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.month,
    required this.selected,
    required this.onPick,
    this.notBefore,
  });

  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;
  final DateTime? notBefore;

  @override
  Widget build(BuildContext context) {
    final blanks = leadingBlanksForMonth(month);
    final total = daysInMonth(month);
    final rows = ((blanks + total) / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: rows * 7,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - blanks + 1;
        if (dayNumber < 1 || dayNumber > total) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, dayNumber);
        final allowed =
            notBefore == null || date.epochDay >= notBefore!.epochDay;
        return _DayCell(
          key: ValueKey('pick-day-${date.epochDay}'),
          date: date,
          isSelected: date.isSameDayAs(selected),
          isToday: date.isSameDayAs(todayDate()),
          onTap: allowed ? () => onPick(date) : null,
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;

  /// Null for a day that cannot be picked, which is drawn greyed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Center(
      child: BrandedSelectionCircle(
        selected: isSelected,
        outlined: isToday,
        size: Brand.daySize,
        child: BrandedText(
          '${date.day}',
          role: isSelected || isToday
              ? BrandedTextRole.action
              : BrandedTextRole.label,
          tone: isSelected
              ? BrandedTone.inverted
              : onTap == null
              ? BrandedTone.muted
              : BrandedTone.primary,
        ),
      ),
    ),
  );
}
