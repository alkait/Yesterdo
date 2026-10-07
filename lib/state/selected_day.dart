import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import 'providers.dart';

/// The day the whole interface is looking at.
class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => todayDate();

  /// Turns the page a day at a time, as a swipe does. Turning is its own
  /// way about, so nothing is kept to go back to.
  void shift(int days) {
    state = state.addDays(days);
    _sentFrom.clear();
  }

  /// Jumps to [date]: from the month grid, a search, a banner's Go, Left
  /// behind or a notification. The day left is kept, so Back can return
  /// to it.
  void select(DateTime date) {
    final from = state;
    state = date.startOfDay;
    if (state != from) _sentFrom.remember(from);
  }

  void jumpToToday() => select(todayDate());

  /// Returns to the day the list was sent from, if it was sent.
  void goBack() {
    final from = ref.read(sentFromProvider);
    if (from == null) return;
    state = from;
    _sentFrom.clear();
  }

  SentFrom get _sentFrom => ref.read(sentFromProvider.notifier);
}

/// Where the list was sent from by a jump, or null when it got where it is
/// on its own. Set and cleared by [SelectedDay] alone.
class SentFrom extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void remember(DateTime day) => state = day;

  void clear() => state = null;
}
