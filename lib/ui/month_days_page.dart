import 'package:flutter/material.dart';

import '../data/repeat_rule.dart';
import 'branded/branded.dart';

/// The screen where the days of a monthly repeat are chosen: any of the
/// first twenty-eight, and the last day of the month. The 29th, 30th and
/// 31st are shown but cannot be picked, because not every month has them.
/// Hands the chosen set back through the navigator, or null when cancelled.
class MonthDaysPage extends StatefulWidget {
  const MonthDaysPage({super.key, required this.initialMonthDays});

  final int initialMonthDays;

  @override
  State<MonthDaysPage> createState() => _MonthDaysPageState();
}

class _MonthDaysPageState extends State<MonthDaysPage> {
  late int _monthDays = widget.initialMonthDays;

  void _toggle(int bit) {
    final flipped = _monthDays ^ bit;
    // Never leave the rule with nothing to fire on.
    if (flipped != 0) setState(() => _monthDays = flipped);
  }

  @override
  Widget build(BuildContext context) => BrandedScaffold(
    children: [
      BrandedAppBar(
        leading: BrandedTextButton(
          label: 'Cancel',
          onTap: () => Navigator.of(context).pop(),
        ),
        center: const BrandedText(
          'Every month',
          role: BrandedTextRole.title,
          align: TextAlign.center,
        ),
        trailing: BrandedTextButton(
          key: const ValueKey('month-days-done'),
          label: 'Done',
          onTap: () => Navigator.of(context).pop(_monthDays),
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
              _MonthDayGrid(monthDays: _monthDays, onToggle: _toggle),
              const SizedBox(height: Brand.gap),
              const BrandedDivider(),
              BrandedOptionRow(
                key: const ValueKey('month-last-day'),
                label: 'Last day of every month',
                selected: _monthDays & RepeatRule.lastDayOfMonthBit != 0,
                onTap: () => _toggle(RepeatRule.lastDayOfMonthBit),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _MonthDayGrid extends StatelessWidget {
  const _MonthDayGrid({required this.monthDays, required this.onToggle});

  final int monthDays;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 7,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    children: [
      for (var day = 1; day <= 31; day++)
        _MonthDayDot(
          key: ValueKey('month-day-$day'),
          day: day,
          selected: monthDays & RepeatRule.monthDayBit(day) != 0,
          onTap: day <= RepeatRule.lastChoosableMonthDay
              ? () => onToggle(RepeatRule.monthDayBit(day))
              : null,
        ),
    ],
  );
}

class _MonthDayDot extends StatelessWidget {
  const _MonthDayDot({
    super.key,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;

  /// Null for a day that cannot be chosen, which is drawn greyed and ignores
  /// the finger.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    enabled: onTap != null,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: BrandedSelectionCircle(
          selected: selected,
          size: Brand.daySize,
          child: BrandedText(
            '$day',
            role: selected ? BrandedTextRole.action : BrandedTextRole.label,
            tone: selected
                ? BrandedTone.inverted
                : onTap == null
                ? BrandedTone.muted
                : BrandedTone.primary,
          ),
        ),
      ),
    ),
  );
}
