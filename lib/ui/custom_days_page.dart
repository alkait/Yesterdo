import 'package:flutter/material.dart';

import '../core/day.dart';
import 'branded/branded.dart';
import 'widgets/month_grid.dart';

/// The screen where the exact days of a custom repeat are chosen: any
/// number of them, from today on, tapped on and off on the month grid.
/// Hands the chosen set back through the navigator, or null when cancelled.
/// Done stays greyed until at least one day is chosen.
class CustomDaysPage extends StatefulWidget {
  const CustomDaysPage({super.key, required this.initialDays, this.notBefore});

  /// Epoch days already chosen.
  final Set<int> initialDays;

  /// The first day that may be chosen; today when null.
  final DateTime? notBefore;

  @override
  State<CustomDaysPage> createState() => _CustomDaysPageState();
}

class _CustomDaysPageState extends State<CustomDaysPage> {
  late final Set<int> _days = {...widget.initialDays};
  late DateTime _month = DateTime(_opening.year, _opening.month);

  DateTime get _first => widget.notBefore ?? todayDate();

  /// The month opened on: the earliest chosen day's, else this one.
  DateTime get _opening {
    if (_days.isEmpty) return _first;
    return dateFromEpochDay(_days.reduce((a, b) => a < b ? a : b));
  }

  void _stepMonth(int amount) =>
      setState(() => _month = DateTime(_month.year, _month.month + amount));

  void _toggle(DateTime date) => setState(() {
    if (!_days.remove(date.epochDay)) _days.add(date.epochDay);
  });

  @override
  Widget build(BuildContext context) => BrandedScaffold(
    children: [
      BrandedAppBar(
        leading: BrandedTextButton(
          label: 'Cancel',
          onTap: () => Navigator.of(context).pop(),
        ),
        center: const BrandedText(
          'Chosen days',
          role: BrandedTextRole.title,
          align: TextAlign.center,
        ),
        trailing: BrandedTextButton(
          key: const ValueKey('custom-days-done'),
          label: 'Done',
          enabled: _days.isNotEmpty,
          onTap: () => Navigator.of(context).pop(_days),
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
                isSelected: (date) => _days.contains(date.epochDay),
                isAllowed: (date) => date.epochDay >= _first.epochDay,
                onPick: _toggle,
              ),
              const SizedBox(height: Brand.gap),
              BrandedText(
                _days.isEmpty
                    ? 'Tap the days the task should come back on.'
                    : '${_days.length} ${_days.length == 1 ? 'day' : 'days'} chosen',
                role: BrandedTextRole.caption,
                tone: BrandedTone.muted,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
