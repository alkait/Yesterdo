import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/sqlite_settings_store.dart';
import 'data/sqlite_todo_store.dart';
import 'platform/device_bridge.dart';
import 'platform/image_sweep.dart';
import 'reminders/local_reminder_scheduler.dart';
import 'state/providers.dart';
import 'sync/cloud_transport.dart';
import 'state/developer_mode.dart';
import 'state/app_sounds.dart';
import 'state/done_sound_choice.dart';
import 'state/last_sound.dart';
import 'state/recent_searches.dart';
import 'state/theme_choice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened before the first frame so the interface never shows a loader.
  final database = await AppDatabase.open();
  final settings = SqliteSettingsStore(database);
  // Read before the first frame too, so the saved look is the first one seen.
  final theme = await ThemeChoice.load(settings);
  final sound = await LastSound.load(settings);
  final developer = await DeveloperMode.load(settings);
  final sounds = await AppSounds.load(settings);
  final doneSound = await DoneSoundChoice.load(settings);
  final searches = await RecentSearches.load(settings);

  final notifications = FlutterLocalNotificationsPlugin();
  const device = MethodChannelDeviceBridge();
  const cloud = MethodChannelCloudTransport();
  final store = SqliteTodoStore(database);
  final images = await device.imagesDirectory();
  final version = await device.appVersion();
  final container = ProviderContainer(
    overrides: [
      todoStoreProvider.overrideWithValue(store),
      imagesDirectoryProvider.overrideWithValue(images),
      appVersionProvider.overrideWithValue(version),
      settingsStoreProvider.overrideWithValue(settings),
      initialThemeChoiceProvider.overrideWithValue(theme),
      initialSoundProvider.overrideWithValue(sound),
      initialDeveloperModeProvider.overrideWithValue(developer),
      initialAppSoundsProvider.overrideWithValue(sounds),
      initialDoneSoundProvider.overrideWithValue(doneSound),
      initialRecentSearchesProvider.overrideWithValue(searches),
      deviceBridgeProvider.overrideWithValue(device),
      cloudTransportProvider.overrideWithValue(cloud),
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
  // topped up at every launch. The widgets are handed today and tomorrow
  // at the same time.
  container.read(reminderSyncProvider).refresh();
  container.read(glanceSyncProvider).refresh();

  // A tapped widget names a task the same way a notification does. Asked
  // for once at launch, for a tap that started the app, and again whenever
  // the device says one has landed.
  Future<void> takeTappedTask() async {
    container
        .read(attentionRequestProvider.notifier)
        .raiseFromPayload(await device.takeTappedTask());
  }

  device.onWidgetTap(takeTappedTask);
  await takeTappedTask();

  // The glance is drawn in the chosen look, so a change of look redraws it.
  container.listen(
    themeChoiceProvider,
    (_, _) => container.read(glanceSyncProvider).refresh(),
  );

  // What another device wrote lands in the store behind the interface, so
  // the day is read again and everything that follows the store follows.
  final sync = container.read(cloudSyncProvider);
  sync.onPulled = () {
    container.read(todosProvider.notifier).refresh();
    container.invalidate(backlogProvider);
  };
  cloud.onChange(sync.nudge);

  runApp(
    UncontrolledProviderScope(container: container, child: const YesterdoApp()),
  );
  // Pictures nobody refers to any more are cleared out once the app is up,
  // and only then is the cloud asked, so a picture just fetched is not
  // swept before the task it belongs to has landed.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await ImageSweep(store, images).run();
    sync.nudge();
  });
}
