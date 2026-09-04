import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reminders/planned_reminder.dart';

/// A task asking to be looked at: raised when its notification is tapped,
/// and answered by the list opening its day and putting up the sheet.
class AttentionRequest {
  const AttentionRequest({required this.day, required this.key});

  final int day;
  final String key;
}

class AttentionRequests extends Notifier<AttentionRequest?> {
  @override
  AttentionRequest? build() => null;

  void raise(int day, String key) =>
      state = AttentionRequest(day: day, key: key);

  /// Raises the request a tapped notification carried, if it is one of ours.
  void raiseFromPayload(String? payload) {
    final parsed = PlannedReminder.parsePayload(payload);
    if (parsed != null) raise(parsed.$1, parsed.$2);
  }

  void clear() => state = null;
}
