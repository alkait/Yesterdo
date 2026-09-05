import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_version.dart';
import '../reminders/reminder_scheduler.dart';
import '../state/developer_mode.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'widgets/done_sound_picker_sheet.dart';
import 'widgets/theme_picker_sheet.dart';

/// The settings screen: which look the app is drawn in, whether the system
/// lets it notify, and the version. Ten taps on the version turn developer
/// mode on; a row then appears to turn it off again.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _versionTaps = 0;

  void _onVersionTap() {
    if (ref.read(developerModeProvider)) return;
    _versionTaps++;
    if (_versionTaps < DeveloperMode.tapsToEnable) return;
    _versionTaps = 0;
    ref.read(developerModeProvider.notifier).set(true);
  }

  /// Not yet asked: ask now. Refused: the system's settings are the only
  /// way back, so open them. Allowed: the settings page is where a sound or
  /// a banner can be turned off, so open that too.
  Future<void> _onNotificationsTap(
    WidgetRef ref,
    ReminderPermission permission,
  ) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    if (permission == ReminderPermission.notAsked) {
      await scheduler.requestPermission();
      ref.invalidate(reminderPermissionProvider);
    } else {
      await scheduler.openSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = ref.watch(themeChoiceProvider);
    final permission = ref.watch(reminderPermissionProvider).value;
    final developer = ref.watch(developerModeProvider);
    final sounds = ref.watch(appSoundsProvider);
    final doneSound = ref.watch(doneSoundProvider);

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
                  'Look',
                  role: BrandedTextRole.caption,
                  tone: BrandedTone.muted,
                ),
                BrandedFieldRow(
                  key: const ValueKey('settings-theme'),
                  label: 'Theme',
                  value: chosen.label,
                  onTap: () => showThemePicker(context),
                ),
                const SizedBox(height: Brand.gap),
                const BrandedText(
                  'Sounds',
                  role: BrandedTextRole.caption,
                  tone: BrandedTone.muted,
                ),
                BrandedToggleRow(
                  key: const ValueKey('settings-sounds'),
                  label: 'App sounds',
                  value: sounds,
                  onChanged: ref.read(appSoundsProvider.notifier).set,
                ),
                const BrandedDivider(),
                BrandedFieldRow(
                  key: const ValueKey('settings-done-sound'),
                  label: 'Done sound',
                  value: doneSound.label,
                  onTap: () => showDoneSoundPicker(context),
                ),
                const SizedBox(height: Brand.gap),
                const BrandedText(
                  'Notifications',
                  role: BrandedTextRole.caption,
                  tone: BrandedTone.muted,
                ),
                BrandedFieldRow(
                  key: const ValueKey('settings-notifications'),
                  label: 'Reminders',
                  value: switch (permission) {
                    null => '',
                    ReminderPermission.notAsked => 'Not asked yet',
                    ReminderPermission.granted => 'Allowed',
                    ReminderPermission.denied => 'Not allowed',
                  },
                  detail: switch (permission) {
                    ReminderPermission.notAsked => 'Tap to allow',
                    ReminderPermission.denied => 'Turn on in Settings',
                    _ => null,
                  },
                  onTap: permission == null
                      ? () {}
                      : () => _onNotificationsTap(ref, permission),
                ),
                const SizedBox(height: Brand.gap),
                const BrandedText(
                  'About',
                  role: BrandedTextRole.caption,
                  tone: BrandedTone.muted,
                ),
                // A plain label, so nobody is invited to tap it; ten taps
                // still turn developer mode on for those who know.
                GestureDetector(
                  key: const ValueKey('settings-version'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _onVersionTap,
                  child: const BrandedFieldRow(
                    label: 'Version',
                    value: appVersion,
                  ),
                ),
                // The done sounds are Headphaze's, under CC BY 4.0, which
                // asks for a credit, and Universfield's, under the Pixabay
                // Content Licence.
                const BrandedFieldRow(
                  label: 'Sounds by',
                  value: 'Headphaze, Universfield',
                  detail: 'Freesound CC BY 4.0, Pixabay licence',
                ),
                if (developer)
                  BrandedTextButton(
                    key: const ValueKey('settings-developer'),
                    label: 'Turn developer mode off',
                    onTap: () =>
                        ref.read(developerModeProvider.notifier).set(false),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
