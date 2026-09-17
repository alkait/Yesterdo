import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/due.dart';
import '../../data/reminder_sound.dart';
import '../branded/branded.dart';
import 'sound_picker_sheet.dart';

/// Asks which reminders to send ahead of a task's time, and what they sound
/// like. The time itself is settled already, on its own sheet; this one
/// hangs off it. Returns the time with the new reminders, or null when the
/// sheet is backed out of.
Future<Due?> showReminderSheet(BuildContext context, {required Due current}) =>
    showBrandedSheet<Due>(
      context,
      (sheetContext) => _ReminderPicker(current: current),
      dismissible: false,
    );

class _ReminderPicker extends ConsumerStatefulWidget {
  const _ReminderPicker({required this.current});

  final Due current;

  @override
  ConsumerState<_ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends ConsumerState<_ReminderPicker> {
  late final Set<int> _reminders = {...widget.current.reminders};
  late ReminderSound _sound = widget.current.sound;

  void _toggle(int before) => setState(() {
    if (!_reminders.remove(before)) _reminders.add(before);
  });

  Future<void> _pickSound() async {
    final chosen = await showSoundPicker(context, current: _sound);
    if (!mounted || chosen == null) return;
    setState(() => _sound = chosen);
  }

  void _done() =>
      Navigator.of(context)
          .pop(widget.current.copyWith(reminders: _reminders, sound: _sound));

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final before in Due.reminderChoices) ...[
          BrandedOptionRow(
            key: ValueKey('reminder-$before'),
            label: widget.current.reminderLabel(
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
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: BrandedTextButton(label: 'Done', onTap: _done),
        ),
      ],
    ),
  );
}
