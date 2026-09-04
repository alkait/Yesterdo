import 'package:flutter/material.dart';

import '../../core/date_labels.dart';
import '../../core/day.dart';
import '../branded/branded.dart';

/// The month's name with an arrow either side.
class MonthBar extends StatelessWidget {
  const MonthBar({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
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
          monthAndYear(month),
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

/// The initials of the days of the week, Sunday first.
class WeekdayStrip extends StatelessWidget {
  const WeekdayStrip({super.key});

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

/// One month of days, seven to a row. Which are marked and which may be
/// tapped is the caller's to say, so the same grid serves picking one day,
/// picking many, and moving a task.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.isSelected,
    required this.onPick,
    this.isAllowed,
  });

  final DateTime month;
  final bool Function(DateTime) isSelected;

  /// Null means every day may be picked.
  final bool Function(DateTime)? isAllowed;

  final ValueChanged<DateTime> onPick;

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
        final allowed = isAllowed?.call(date) ?? true;
        return _DayCell(
          key: ValueKey('pick-day-${date.epochDay}'),
          date: date,
          isSelected: isSelected(date),
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
