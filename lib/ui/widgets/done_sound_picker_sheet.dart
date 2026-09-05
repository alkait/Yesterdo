import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/done_sound.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// Offers the done sounds. A tap chooses one at once and plays it, so it is
/// heard as it is chosen, and the sheet stays up until Done.
Future<void> showDoneSoundPicker(BuildContext context) =>
    showBrandedSheet<void>(context, (sheetContext) => const _DoneSoundPicker());

class _DoneSoundPicker extends ConsumerWidget {
  const _DoneSoundPicker();

  void _choose(WidgetRef ref, DoneSound sound) {
    ref.read(doneSoundProvider.notifier).select(sound);
    ref.read(deviceBridgeProvider).playDone(sound);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(doneSoundProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, sound) in DoneSound.values.indexed) ...[
          if (index > 0) const BrandedDivider(),
          BrandedOptionRow(
            key: ValueKey('done-sound-${sound.name}'),
            label: sound.label,
            icon: Icons.volume_up_outlined,
            selected: sound == chosen,
            onTap: () => _choose(ref, sound),
          ),
        ],
        const SizedBox(height: 8),
        BrandedTextButton(
          label: 'Done',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
