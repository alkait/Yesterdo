import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A task that was saved onto a day other than the one being looked at.
///
/// Raised when the editor is left, and answered by the banner at the foot of
/// the list, which says where the task went and offers to go there.
class DayNotice {
  const DayNotice({required this.line, required this.day});

  /// The task's opening line, which is what the banner shows.
  final String line;

  /// Where it went, as a count of days since the epoch.
  final int day;
}

class DayNotices extends Notifier<DayNotice?> {
  @override
  DayNotice? build() => null;

  void raise({required String line, required int day}) =>
      state = DayNotice(line: line, day: day);

  void clear() => state = null;
}
