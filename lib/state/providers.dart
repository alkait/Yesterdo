import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/day.dart';
import '../data/done_sound.dart';
import '../data/reminder_sound.dart';
import '../data/repeat_rule.dart';
import '../data/search.dart';
import '../data/settings_store.dart';
import '../data/todo.dart';
import '../data/todo_store.dart';
import '../glance/glance_planner.dart';
import '../glance/glance_sync.dart';
import '../platform/device_bridge.dart';
import '../reminders/reminder_planner.dart';
import '../reminders/reminder_scheduler.dart';
import '../reminders/reminder_sync.dart';
import '../sync/cloud_status.dart';
import '../sync/cloud_sync.dart';
import '../sync/cloud_transport.dart';
import 'app_sounds.dart';
import 'attention_request.dart';
import 'backlog.dart';
import 'backlog_controller.dart';
import 'cloud_status_notifier.dart';
import 'day_notice.dart';
import 'developer_mode.dart';
import 'done_sound_choice.dart';
import 'last_sound.dart';
import 'recent_searches.dart';
import 'repeat_history.dart';
import 'selected_day.dart';
import 'spotlight.dart';
import 'theme_choice.dart';
import 'todos_controller.dart';

/// Bound to the opened database in `main`. Riverpod is the only state
/// mechanism in this app; nothing else holds shared state.
final todoStoreProvider = Provider<TodoStore>(
  (ref) => throw StateError('todoStoreProvider must be overridden'),
);

final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);

/// The day the list was sent from by a jump, for Back to return to.
final sentFromProvider = NotifierProvider<SentFrom, DateTime?>(SentFrom.new);

final todosProvider = AsyncNotifierProvider<TodosController, List<Todo>>(
  TodosController.new,
);

/// The moment it is now. Tests bind a clock they can turn by hand, so a task
/// can be watched falling due.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Bound to the opened database in `main`, alongside the todo store.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw StateError('settingsStoreProvider must be overridden'),
);

/// The look in force when the app came up. `main` overrides it with the
/// saved choice; left alone, it is the one the app ships in.
final initialThemeChoiceProvider = Provider<AppThemeChoice>(
  (ref) => AppThemeChoice.fallback,
);

final themeChoiceProvider = NotifierProvider<ThemeChoice, AppThemeChoice>(
  ThemeChoice.new,
);

/// Bound to the system's notifications in `main`; tests bind a recorder.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => throw StateError('reminderSchedulerProvider must be overridden'),
);

/// What was left undone on earlier days. Read afresh after every write,
/// through [TodosController], and whenever the app wakes.
final backlogProvider = AsyncNotifierProvider<BacklogController, Backlog>(
  BacklogController.new,
);

final reminderSyncProvider = Provider<ReminderSync>(
  (ref) => ReminderSync(
    ReminderPlanner(ref.watch(todoStoreProvider)),
    ref.watch(reminderSchedulerProvider),
    ref.watch(todoStoreProvider),
    ref.watch(deviceBridgeProvider),
  ),
);

/// Keeps the Lock Screen and Home Screen widgets matching the store. Watches
/// the look, so a change of theme redraws them in the new accent.
final glanceSyncProvider = Provider<GlanceSync>(
  (ref) => GlanceSync(
    GlancePlanner(ref.watch(todoStoreProvider)),
    ref.watch(deviceBridgeProvider),
    ref.watch(themeChoiceProvider),
  ),
);

/// Bound to the device's CloudKit in `main`; tests bind a cloud of their
/// own, or leave it, which is no cloud at all.
final cloudTransportProvider = Provider<CloudTransport>(
  (ref) => const NoCloudTransport(),
);

/// Keeps the store and the cloud matching. Nudged after every write, on
/// launch, on return to the front, and when another device has written.
/// Says where it stands through [cloudStatusProvider].
final cloudSyncProvider = Provider<CloudSync>(
  (ref) => CloudSync(
    ref.watch(todoStoreProvider),
    ref.watch(cloudTransportProvider),
    clock: ref.watch(clockProvider),
  )..onStatus = ref.read(cloudStatusProvider.notifier).set,
);

/// Where the sync stands, for Settings to read.
final cloudStatusProvider = NotifierProvider<CloudStatusNotifier, CloudStatus>(
  CloudStatusNotifier.new,
);

/// The rule behind a repeating task, as it stands on [day]; null for a
/// one-off or a rule since gone.
final ruleForProvider = FutureProvider.autoDispose
    .family<RepeatRule?, ({int day, int? recurrenceId})>((ref, at) async {
      if (at.recurrenceId == null) return null;
      final rules = await ref.watch(todoStoreProvider).recurrencesFor(at.day);
      for (final rule in rules) {
        if (rule.id == at.recurrenceId) return rule.rule;
      }
      return null;
    });

/// How a repeating task has gone, every showing from its first day to
/// today. Read afresh each time it is looked at.
final repeatHistoryProvider = FutureProvider.autoDispose
    .family<RepeatHistory, int>(
      (ref, recurrenceId) => RepeatHistory.read(
        ref.watch(todoStoreProvider),
        recurrenceId: recurrenceId,
        today: ref.watch(clockProvider)().epochDay,
      ),
    );

/// A task saved onto another day, waiting for the banner to say so. Null
/// while there is nothing to say.
final dayNoticeProvider = NotifierProvider<DayNotices, DayNotice?>(
  DayNotices.new,
);

/// The task a tapped notification asked to see, until the list has shown it.
final attentionRequestProvider =
    NotifierProvider<AttentionRequests, AttentionRequest?>(
      AttentionRequests.new,
    );

/// A task to be pointed out on its day, as one found by a search, until
/// the list has shown it. Null while there is nothing to point out.
final spotlightProvider = NotifierProvider<Spotlights, Spotlight?>(
  Spotlights.new,
);

/// Bound to the device in `main`; tests bind a recorder.
final deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) => throw StateError('deviceBridgeProvider must be overridden'),
);

/// Whether the system lets the app notify. Read afresh whenever the app
/// comes back to the front, since the answer can change in Settings.
final reminderPermissionProvider = FutureProvider<ReminderPermission>(
  (ref) => ref.watch(reminderSchedulerProvider).permission(),
);

/// The sound saved from last time, bound in `main` before the first frame.
final initialSoundProvider = Provider<ReminderSound>(
  (ref) => ReminderSound.system,
);

/// The sound a new reminder starts from: whatever was chosen last.
final lastSoundProvider = NotifierProvider<LastSound, ReminderSound>(
  LastSound.new,
);

/// Where pictures are kept, read from the device in `main` before the
/// first frame; tests bind a folder of their own.
final imagesDirectoryProvider = Provider<String>(
  (ref) => throw StateError('imagesDirectoryProvider must be overridden'),
);

/// The version the app was built as, read from the device in `main` before
/// the first frame.
final appVersionProvider = Provider<String>((ref) => '');

/// Whether the app's own sounds were on last time, bound in `main` before
/// the first frame.
final initialAppSoundsProvider = Provider<bool>((ref) => true);

final appSoundsProvider = NotifierProvider<AppSounds, bool>(AppSounds.new);

/// The done sound saved from last time, bound in `main` before the first
/// frame.
final initialDoneSoundProvider = Provider<DoneSound>(
  (ref) => DoneSound.fallback,
);

final doneSoundProvider = NotifierProvider<DoneSoundChoice, DoneSound>(
  DoneSoundChoice.new,
);

/// Whether developer mode was on last time, bound in `main` before the
/// first frame.
final initialDeveloperModeProvider = Provider<bool>((ref) => false);

final developerModeProvider = NotifierProvider<DeveloperMode, bool>(
  DeveloperMode.new,
);

/// The searches made last time, newest first, bound in `main` before the
/// first frame.
final initialRecentSearchesProvider = Provider<List<String>>((ref) => const []);

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(
  RecentSearches.new,
);

/// What answers to a search, latest day first. Read afresh for each query.
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<SearchHit>, String>(
      (ref, query) => ref
          .watch(todoStoreProvider)
          .search(query, today: ref.watch(clockProvider)().epochDay),
    );
