import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reminder_sound.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// Asks what a reminder should sound like. Each row plays its sound when
/// tapped, so it can be heard before Done is pressed. Returns the choice, or
/// null when the sheet is swiped away.
Future<ReminderSound?> showSoundPicker(
  BuildContext context, {
  required ReminderSound current,
}) => showBrandedSheet<ReminderSound>(
  context,
  (sheetContext) => _SoundPicker(current: current),
);

class _SoundPicker extends ConsumerStatefulWidget {
  const _SoundPicker({required this.current});

  final ReminderSound current;

  @override
  ConsumerState<_SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends ConsumerState<_SoundPicker> {
  late ReminderSound _sound = widget.current;

  void _choose(ReminderSound sound) {
    setState(() => _sound = sound);
    ref.read(deviceBridgeProvider).previewSound(sound);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (index, sound) in ReminderSound.values.indexed) ...[
        if (index > 0) const BrandedDivider(),
        BrandedOptionRow(
          key: ValueKey('sound-${sound.name}'),
          label: sound.label,
          icon: Icons.volume_up_outlined,
          selected: _sound == sound,
          onTap: () => _choose(sound),
        ),
      ],
      const SizedBox(height: 8),
      BrandedTextButton(
        label: 'Done',
        onTap: () => Navigator.of(context).pop(_sound),
      ),
    ],
  );
}
