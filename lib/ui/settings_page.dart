import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reminders/reminder_scheduler.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'widgets/theme_picker_sheet.dart';

/// The settings screen: which look the app is drawn in, and whether the
/// system lets it notify.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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

  /// The test goes out a few seconds from now, after permission if it has
  /// not been asked for yet.
  static const testDelay = Duration(seconds: 10);

  Future<void> _sendTest(WidgetRef ref, ReminderPermission? permission) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    if (permission == ReminderPermission.notAsked) {
      await scheduler.requestPermission();
      ref.invalidate(reminderPermissionProvider);
    }
    await scheduler.sendTest(
      at: ref.read(clockProvider)().add(testDelay),
      sound: ref.read(lastSoundProvider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(themeChoiceProvider);
    final permission = ref.watch(reminderPermissionProvider).value;

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
                const BrandedDivider(),
                BrandedOptionRow(
                  key: const ValueKey('settings-test-reminder'),
                  label: 'Send a test reminder',
                  detail: 'Arrives in ${testDelay.inSeconds} seconds',
                  icon: Icons.send_outlined,
                  onTap: () => _sendTest(ref, permission),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
