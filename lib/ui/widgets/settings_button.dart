import 'package:flutter/material.dart';

import '../branded/branded.dart';
import '../settings_page.dart';

/// The gear at the bottom right. It opens the settings screen.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => BrandedIconButton(
    icon: Icons.settings_outlined,
    label: 'Settings',
    size: BrandedIconSize.medium,
    onTap: () => openBrandedPage<void>(context, (_) => const SettingsPage()),
  );
}
