import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_size.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// Offers the text sizes. A tap applies one at once, and the sheet stays
/// up so the change can be seen, on the sheet itself and behind it, before
/// it is swiped away.
Future<void> showTextSizePicker(BuildContext context) =>
    showBrandedSheet<void>(context, (sheetContext) => const _TextSizePicker());

class _TextSizePicker extends ConsumerWidget {
  const _TextSizePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(textSizeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, size) in AppTextSize.values.indexed) ...[
          if (index > 0) const BrandedDivider(),
          BrandedOptionRow(
            key: ValueKey('text-size-${size.name}'),
            label: size.label,
            icon: Icons.text_fields_rounded,
            selected: size == chosen,
            onTap: () => ref.read(textSizeProvider.notifier).select(size),
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
