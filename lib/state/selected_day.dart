import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';

/// The day the whole interface is looking at.
class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => todayDate();

  void shift(int days) => state = state.addDays(days);

  void select(DateTime date) => state = date.startOfDay;

  void jumpToToday() => state = todayDate();
}
