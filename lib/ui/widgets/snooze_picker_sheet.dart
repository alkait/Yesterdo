import 'package:flutter/material.dart';

import '../../core/date_labels.dart';
import '../../data/due.dart';
import '../branded/branded.dart';

/// Asks how long to put a calling task off: a few set stretches, or a time
/// of the person's own choosing later today. Returns the minute of the day
/// to call again at, or null when backed out of.
Future<int?> showSnoozePicker(
  BuildContext context, {
  required int nowMinute,
  required bool twentyFourHour,
}) async {
  final choice = await showBrandedSheet<_Snooze>(
    context,
    (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, stretch) in Due.snoozeStretches.indexed) ...[
          if (index > 0) const BrandedDivider(),
          BrandedOptionRow(
            key: ValueKey('snooze-$stretch'),
            label: Due.stretchLabel(stretch),
            detail: timeLabel(
              Due.clampMinute(nowMinute + stretch),
              twentyFourHour: twentyFourHour,
            ),
            icon: Icons.snooze_rounded,
            onTap: () => Navigator.of(sheetContext).pop(_Snooze(stretch)),
          ),
        ],
        const BrandedDivider(),
        BrandedOptionRow(
          key: const ValueKey('snooze-later'),
          label: 'Later today',
          detail: 'Pick a time',
          icon: Icons.schedule_rounded,
          onTap: () => Navigator.of(sheetContext).pop(const _Snooze(null)),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
  if (choice == null) return null;
  if (choice.stretch case final stretch?) {
    return Due.clampMinute(nowMinute + stretch);
  }
  if (!context.mounted) return null;
  return showLaterTodaySheet(context, nowMinute: nowMinute);
}

class _Snooze {
  const _Snooze(this.stretch);

  /// Minutes from now, or null for a time of the person's own.
  final int? stretch;
}

/// A time wheel for later today. Done stays greyed while the time on the
/// wheel has already gone by.
Future<int?> showLaterTodaySheet(
  BuildContext context, {
  required int nowMinute,
}) => showBrandedSheet<int>(
  context,
  (sheetContext) => _LaterToday(nowMinute: nowMinute),
  dismissible: false,
);

class _LaterToday extends StatefulWidget {
  const _LaterToday({required this.nowMinute});

  final int nowMinute;

  @override
  State<_LaterToday> createState() => _LaterTodayState();
}

class _LaterTodayState extends State<_LaterToday> {
  /// Opens an hour on, rounded to the wheel's step.
  late int _minute = Due.clampMinute(widget.nowMinute + 60);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandedTimeWheel(
        minute: _minute,
        onChanged: (minute) => setState(() => _minute = minute),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BrandedTextButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(),
          ),
          BrandedTextButton(
            key: const ValueKey('later-today-done'),
            label: 'Done',
            enabled: _minute > widget.nowMinute,
            onTap: () => Navigator.of(context).pop(_minute),
          ),
        ],
      ),
    ],
  );
}
