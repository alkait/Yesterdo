import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// Offers the looks. A tap applies one at once, and the sheet stays up so
/// the change can be seen behind it before it is swiped away.
Future<void> showThemePicker(BuildContext context) =>
    showBrandedSheet<void>(context, (sheetContext) => const _ThemePicker());

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(themeChoiceProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, choice) in AppThemeChoice.values.indexed) ...[
          if (index > 0) const BrandedDivider(),
          BrandedOptionRow(
            key: ValueKey('theme-${choice.name}'),
            label: choice.label,
            leading: BrandedThemeSwatch(choice),
            selected: choice == chosen,
            onTap: () => ref.read(themeChoiceProvider.notifier).select(choice),
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
