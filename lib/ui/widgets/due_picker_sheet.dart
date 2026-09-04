import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/due.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// What the due chooser hands back. Wrapped so that backing out (null) can
/// be told from clearing the time (a pick holding null).
class DuePick {
  const DuePick(this.due);

  final Due? due;
}

/// Asks when in the day a task is due, and whether to be reminded. Returns
/// the pick, or null when the sheet is swiped away.
Future<DuePick?> showDuePicker(BuildContext context, {required Due? current}) =>
    showBrandedSheet<DuePick>(
      context,
      (sheetContext) => _DuePicker(current: current),
    );

class _DuePicker extends ConsumerStatefulWidget {
  const _DuePicker({required this.current});

  final Due? current;

  @override
  ConsumerState<_DuePicker> createState() => _DuePickerState();
}

class _DuePickerState extends ConsumerState<_DuePicker> {
  late int _minute = widget.current?.minute ?? _nextHour();
  late int? _reminder = widget.current?.reminder;

  /// A fresh time opens on the coming hour, a reasonable first guess.
  int _nextHour() {
    final now = ref.read(clockProvider)();
    return ((now.hour + 1) % 24) * 60;
  }

  void _done() =>
      Navigator.of(context)
          .pop(DuePick(Due(minute: _minute, reminder: _reminder)));

  void _clear() => Navigator.of(context).pop(const DuePick(null));

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandedTimeWheel(
          minute: _minute,
          onChanged: (minute) => setState(() => _minute = minute),
        ),
        const BrandedDivider(),
        for (final (index, choice) in [
          null,
          ...Due.reminderChoices,
        ].indexed) ...[
          if (index > 0) const BrandedDivider(),
          BrandedOptionRow(
            key: ValueKey('reminder-${choice ?? 'none'}'),
            label: Due.reminderLabel(choice),
            icon: choice == null
                ? Icons.notifications_off_outlined
                : Icons.notifications_active_outlined,
            selected: _reminder == choice,
            onTap: () => setState(() => _reminder = choice),
          ),
        ],
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
    ),
  );
}
