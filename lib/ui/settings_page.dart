import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../state/providers.dart';
import 'branded/branded.dart';

/// The settings screen. For now it holds one thing: which look the app is
/// drawn in. A tap applies the choice straight away, so the screen itself
/// shows what was picked.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(themeChoiceProvider);

    return BrandedScaffold(
      children: [
        BrandedAppBar(
          leading: BrandedTextButton(
            label: 'Done',
            onTap: () => Navigator.of(context).pop(),
          ),
          center: const BrandedText(
            'Settings',
            role: BrandedTextRole.title,
            align: TextAlign.center,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Brand.gutter,
              vertical: Brand.gap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandedText(
                  'Theme',
                  role: BrandedTextRole.caption,
                  tone: BrandedTone.muted,
                ),
                for (final choice in AppThemeChoice.values) ...[
                  if (choice != AppThemeChoice.values.first)
                    const BrandedDivider(),
                  BrandedOptionRow(
                    key: ValueKey('theme-${choice.name}'),
                    label: choice.label,
                    leading: BrandedThemeSwatch(choice),
                    selected: choice == chosen,
                    onTap: () =>
                        ref.read(themeChoiceProvider.notifier).select(choice),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
