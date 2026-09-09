import '../core/app_theme.dart';
import '../platform/device_bridge.dart';
import 'glance.dart';
import 'glance_planner.dart';

/// Keeps the Lock Screen and Home Screen widgets matching the store. Run
/// after anything changes, on launch, and whenever the app wakes, beside the
/// reminders.
class GlanceSync {
  const GlanceSync(this._planner, this._device, this._choice);

  final GlancePlanner _planner;
  final DeviceBridge _device;
  final AppThemeChoice _choice;

  Future<void> refresh({DateTime? now}) async {
    final tasks = await _planner.plan(now: now ?? DateTime.now());
    await _device.showOnWidgets(
      Glance(tasks: tasks, choice: _choice).encode(),
    );
  }
}
