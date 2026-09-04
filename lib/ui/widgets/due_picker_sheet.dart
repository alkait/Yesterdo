import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/due.dart';
import '../../data/reminder_sound.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'sound_picker_sheet.dart';

/// What the due chooser hands back. Wrapped so that backing out (null) can
/// be told from clearing the time (a pick holding null).
class DuePick {
  const DuePick(this.due);

  final Due? due;
}

/// Asks when in the day a task is due, which reminders to send ahead of it
/// and what they sound like. Returns the pick, or null when the sheet is
/// swiped away.
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
  late final Set<int> _reminders = {...?widget.current?.reminders};
  // A fresh time starts from the sound chosen last time.
  late ReminderSound _sound =
      widget.current?.sound ?? ref.read(lastSoundProvider);

  /// A fresh time opens on the coming hour, a reasonable first guess.
  int _nextHour() {
    final now = ref.read(clockProvider)();
    return ((now.hour + 1) % 24) * 60;
  }

  void _toggle(int before) => setState(() {
    if (!_reminders.remove(before)) _reminders.add(before);
  });

  Future<void> _pickSound() async {
    final chosen = await showSoundPicker(context, current: _sound);
    if (!mounted || chosen == null) return;
    setState(() => _sound = chosen);
  }

  void _done() => Navigator.of(context)
      .pop(DuePick(Due(minute: _minute, reminders: _reminders, sound: _sound)));

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
        for (final before in Due.reminderChoices) ...[
          BrandedOptionRow(
            key: ValueKey('reminder-$before'),
            label: Due(minute: _minute).reminderLabel(
              before,
              twentyFourHour: MediaQuery.alwaysUse24HourFormatOf(context),
            ),
            icon: Icons.notifications_active_outlined,
            selected: _reminders.contains(before),
            onTap: () => _toggle(before),
          ),
          const BrandedDivider(),
        ],
        BrandedFieldRow(
          key: const ValueKey('reminder-sound'),
          label: 'Sound',
          value: _sound.label,
          onTap: _pickSound,
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
    ),
  );
}
