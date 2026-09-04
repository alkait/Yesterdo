import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'month_grid.dart';

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
      MonthBar(
        month: _month,
        onPrevious: () => _stepMonth(-1),
        onNext: () => _stepMonth(1),
      ),
      const SizedBox(height: 4),
      const WeekdayStrip(),
      const SizedBox(height: 4),
      MonthGrid(
        month: _month,
        isSelected: (date) => date.isSameDayAs(widget.selected),
        isAllowed: widget.notBefore == null
            ? null
            : (date) => date.epochDay >= widget.notBefore!.epochDay,
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
