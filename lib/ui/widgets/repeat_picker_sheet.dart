import 'package:flutter/material.dart';

import '../../core/date_labels.dart';
import '../../core/day.dart';
import '../../data/repeat_rule.dart';
import '../branded/branded.dart';
import '../custom_days_page.dart';
import '../month_days_page.dart';

/// Asks how often a task should come back. Returns the chosen rule, or null
/// for a task that happens once.
Future<RepeatRule?> showRepeatPicker(
  BuildContext context, {
  required int anchorDay,
  required RepeatRule? current,
}) => showBrandedSheet<RepeatRule?>(
  context,
  (sheetContext) => _RepeatPicker(anchorDay: anchorDay, current: current),
  dismissible: false,
);

class _RepeatPicker extends StatefulWidget {
  const _RepeatPicker({required this.anchorDay, required this.current});

  /// The day being looked at. Defaults come from it, and a new rule starts on
  /// it so the task never reaches back over days already gone.
  final int anchorDay;

  final RepeatRule? current;

  @override
  State<_RepeatPicker> createState() => _RepeatPickerState();
}

class _RepeatPickerState extends State<_RepeatPicker> {
  late RepeatKind? _kind = widget.current?.kind;

  // A rule only fills in the field its own kind uses, so the others fall back
  // to the day being looked at rather than to a leftover value.
  //
  // These read `widget.current`, never `_kind`. A late initializer runs on
  // first use, which may be long after the user has changed the kind.
  late int _weekdays = widget.current?.kind == RepeatKind.weekly
      ? widget.current!.weekdays
      : RepeatRule.weekdayBit(dateFromEpochDay(widget.anchorDay).weekday);
  late int _monthDays = widget.current?.kind == RepeatKind.monthly
      ? widget.current!.monthDays
      : _monthDaysFor(dateFromEpochDay(widget.anchorDay).day);

  /// The day being looked at, as a first choice. Past the 28th it is a day
  /// the chooser cannot offer, so the last day stands in for it.
  static int _monthDaysFor(int day) => day <= RepeatRule.lastChoosableMonthDay
      ? RepeatRule.monthDayBit(day)
      : RepeatRule.lastDayOfMonthBit;

  late Set<int> _days = widget.current?.kind == RepeatKind.custom
      ? widget.current!.days
      : const <int>{};

  RepeatRule? get _rule => switch (_kind) {
    null => null,
    RepeatKind.daily => RepeatRule.daily(_start),
    RepeatKind.weekly => RepeatRule.weekly(_start, _weekdays),
    RepeatKind.monthly => RepeatRule.monthly(_start, _monthDays),
    RepeatKind.custom => RepeatRule.custom(_days),
  };

  /// Opens the day chooser on its own screen. Coming back with days makes
  /// the rule custom; backing out leaves things as they were.
  Future<void> _chooseCustomDays() async {
    final chosen = await openBrandedPage<Set<int>>(
      context,
      (_) => CustomDaysPage(
        initialDays: _days,
        notBefore: dateFromEpochDay(widget.anchorDay),
      ),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _kind = RepeatKind.custom;
      _days = chosen;
    });
  }

  /// Opens the day chooser on its own screen. Coming back with a choice makes
  /// the rule monthly; backing out leaves things as they were.
  Future<void> _chooseMonthDays() async {
    final chosen = await openBrandedPage<int>(
      context,
      (_) => MonthDaysPage(initialMonthDays: _monthDays),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _kind = RepeatKind.monthly;
      _monthDays = chosen;
    });
  }

  /// An existing rule keeps its own beginning; a new one starts here.
  int get _start => widget.current?.startDay ?? widget.anchorDay;

  void _toggleWeekday(int weekday) {
    setState(() {
      final flipped = _weekdays ^ RepeatRule.weekdayBit(weekday);
      // Never leave a weekly rule with nothing to fire on.
      if (flipped != 0) _weekdays = flipped;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandedOptionRow(
        label: 'Never',
        selected: _kind == null,
        onTap: () => setState(() => _kind = null),
      ),
      const BrandedDivider(),
      BrandedOptionRow(
        label: 'Every day',
        selected: _kind == RepeatKind.daily,
        onTap: () => setState(() => _kind = RepeatKind.daily),
      ),
      const BrandedDivider(),
      BrandedOptionRow(
        label: 'Every week',
        selected: _kind == RepeatKind.weekly,
        onTap: () => setState(() => _kind = RepeatKind.weekly),
      ),
      if (_kind == RepeatKind.weekly)
        _WeekdayToggles(weekdays: _weekdays, onToggle: _toggleWeekday),
      const BrandedDivider(),
      BrandedOptionRow(
        label: 'Every month',
        detail: _kind == RepeatKind.monthly
            ? RepeatRule.monthDaysLabel(_monthDays)
            : null,
        selected: _kind == RepeatKind.monthly,
        onTap: _chooseMonthDays,
      ),
      const BrandedDivider(),
      BrandedOptionRow(
        label: 'Custom',
        detail: _kind == RepeatKind.custom
            ? RepeatRule.customDaysLabel(_days.toList()..sort())
            : 'Exact days, chosen on a calendar',
        selected: _kind == RepeatKind.custom,
        onTap: _chooseCustomDays,
      ),
      const SizedBox(height: 8),
      BrandedTextButton(
        label: 'Done',
        onTap: () => Navigator.of(context).pop(_rule),
      ),
    ],
  );
}

class _WeekdayToggles extends StatelessWidget {
  const _WeekdayToggles({required this.weekdays, required this.onToggle});

  final int weekdays;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shown Sunday first to match the month grid, though a weekday is
        // stored the way DateTime counts it, with Monday as one.
        for (var column = 0; column < 7; column++)
          _WeekdayDot(
            key: ValueKey('repeat-weekday-${column == 0 ? 7 : column}'),
            weekday: column == 0 ? 7 : column,
            initial: weekdayInitials[column],
            selected:
                weekdays & RepeatRule.weekdayBit(column == 0 ? 7 : column) != 0,
            onTap: onToggle,
          ),
      ],
    ),
  );
}

class _WeekdayDot extends StatelessWidget {
  const _WeekdayDot({
    super.key,
    required this.weekday,
    required this.initial,
    required this.selected,
    required this.onTap,
  });

  final int weekday;
  final String initial;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: weekdayName(weekday),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(weekday),
      child: BrandedSelectionCircle(
        selected: selected,
        outlined: !selected,
        size: Brand.daySize,
        child: BrandedText(
          initial,
          role: BrandedTextRole.label,
          tone: selected ? BrandedTone.inverted : BrandedTone.primary,
        ),
      ),
    ),
  );
}
