import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/sqlite_settings_store.dart';
import 'data/sqlite_todo_store.dart';
import 'platform/device_bridge.dart';
import 'reminders/local_reminder_scheduler.dart';
import 'state/providers.dart';
import 'state/last_sound.dart';
import 'state/theme_choice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened before the first frame so the interface never shows a loader.
  final database = await AppDatabase.open();
  final settings = SqliteSettingsStore(database);
  // Read before the first frame too, so the saved look is the first one seen.
  final theme = await ThemeChoice.load(settings);
  final sound = await LastSound.load(settings);

  final notifications = FlutterLocalNotificationsPlugin();
  const device = MethodChannelDeviceBridge();
  final container = ProviderContainer(
    overrides: [
      todoStoreProvider.overrideWithValue(SqliteTodoStore(database)),
      settingsStoreProvider.overrideWithValue(settings),
      initialThemeChoiceProvider.overrideWithValue(theme),
      initialSoundProvider.overrideWithValue(sound),
      deviceBridgeProvider.overrideWithValue(device),
      reminderSchedulerProvider.overrideWithValue(
        LocalReminderScheduler(notifications, device),
      ),
    ],
  );

  // Permission is not asked for here. It is asked the first time a reminder
  // is chosen, when the reason for it is in view.
  await notifications.initialize(
    settings: LocalReminderScheduler.initializationSettings,
    onDidReceiveNotificationResponse: (response) => container
        .read(attentionRequestProvider.notifier)
        .raiseFromPayload(response.payload),
  );
  // Tapped from cold: the request is raised before the first frame, and the
  // list answers it as soon as the day is on screen.
  final launch = await notifications.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) {
    container
        .read(attentionRequestProvider.notifier)
        .raiseFromPayload(launch!.notificationResponse?.payload);
  }
  // Notifications are laid down for a window of days, so the window is
  // topped up at every launch.
  container.read(reminderSyncProvider).refresh();

  runApp(
    UncontrolledProviderScope(container: container, child: const RemindMeApp()),
  );
}
