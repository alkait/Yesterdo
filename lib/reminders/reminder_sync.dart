import '../core/day.dart';
import '../data/todo_store.dart';
import '../platform/device_bridge.dart';
import 'reminder_planner.dart';
import 'reminder_scheduler.dart';

/// Keeps the system's pending notifications, and the number on the app
/// icon, matching the store. Run after anything changes and whenever the
/// app wakes.
class ReminderSync {
  const ReminderSync(this._planner, this._scheduler, this._store, this._device);

  final ReminderPlanner _planner;
  final ReminderScheduler _scheduler;
  final TodoStore _store;
  final DeviceBridge _device;

  Future<void> refresh({DateTime? now}) async {
    final moment = now ?? DateTime.now();
    final plan = await _planner.plan(now: moment);
    await _scheduler.replaceAll(plan);
    await _device.setBadge(await openToday(now: moment));
  }

  /// How many of today's tasks are still to do: what the icon shows. A
  /// waved-away task still counts, since it is not done.
  Future<int> openToday({required DateTime now}) async {
    final todos = await _store.todosOn(now.epochDay);
    return todos.where((todo) => !todo.done).length;
  }
}
