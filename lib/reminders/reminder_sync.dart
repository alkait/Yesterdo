import 'reminder_planner.dart';
import 'reminder_scheduler.dart';

/// Keeps the system's pending notifications matching the store. Run after
/// anything changes and whenever the app wakes.
class ReminderSync {
  const ReminderSync(this._planner, this._scheduler);

  final ReminderPlanner _planner;
  final ReminderScheduler _scheduler;

  Future<void> refresh({DateTime? now}) async {
    final plan = await _planner.plan(now: now ?? DateTime.now());
    await _scheduler.replaceAll(plan);
  }
}
