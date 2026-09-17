import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../branded/branded.dart';

/// What the time chooser hands back. Wrapped so that backing out (null) can
/// be told from clearing the time (a pick holding null).
class TimePick {
  const TimePick(this.minute);

  /// The minute of the day, or null for no time at all.
  final int? minute;
}

/// Asks when in the day a task is due: a wheel, and nothing else. Returns
/// the pick, or null when the sheet is backed out of.
Future<TimePick?> showTimeSheet(
  BuildContext context, {
  required int? current,
}) => showBrandedSheet<TimePick>(
  context,
  (sheetContext) => _TimePicker(current: current),
  dismissible: false,
);

class _TimePicker extends ConsumerStatefulWidget {
  const _TimePicker({required this.current});

  final int? current;

  @override
  ConsumerState<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends ConsumerState<_TimePicker> {
  late int _minute = widget.current ?? _nextHour();

  /// A fresh time opens on the coming hour, a reasonable first guess.
  int _nextHour() {
    final now = ref.read(clockProvider)();
    return ((now.hour + 1) % 24) * 60;
  }

  void _done() => Navigator.of(context).pop(TimePick(_minute));

  void _clear() => Navigator.of(context).pop(const TimePick(null));

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
            label: 'Clear',
            tone: BrandedTone.danger,
            onTap: _clear,
          ),
          BrandedTextButton(label: 'Done', onTap: _done),
        ],
      ),
    ],
  );
}
