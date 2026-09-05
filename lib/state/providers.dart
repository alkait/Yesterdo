import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/day.dart';
import '../data/reminder_sound.dart';
import '../data/repeat_rule.dart';
import '../data/settings_store.dart';
import '../data/todo.dart';
import '../data/todo_store.dart';
import '../platform/device_bridge.dart';
import '../reminders/reminder_planner.dart';
import '../reminders/reminder_scheduler.dart';
import '../reminders/reminder_sync.dart';
import 'attention_request.dart';
import 'backlog.dart';
import 'backlog_controller.dart';
import 'developer_mode.dart';
import 'last_sound.dart';
import 'repeat_history.dart';
import 'selected_day.dart';
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

/// The task a tapped notification asked to see, until the list has shown it.
final attentionRequestProvider =
    NotifierProvider<AttentionRequests, AttentionRequest?>(
      AttentionRequests.new,
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

/// Whether developer mode was on last time, bound in `main` before the
/// first frame.
final initialDeveloperModeProvider = Provider<bool>((ref) => false);

final developerModeProvider = NotifierProvider<DeveloperMode, bool>(
  DeveloperMode.new,
);
