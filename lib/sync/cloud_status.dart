import '../core/date_labels.dart';

/// Where the sync stands, as Settings reads it.
enum CloudPhase {
  /// The device has no iCloud account, so nothing is sent.
  notSignedIn,

  /// Signed in, but no run has finished since the app came up.
  never,

  /// A run is under way.
  syncing,

  /// The last run went through and nothing is waiting.
  upToDate,

  /// The last run failed, so the log still holds changes to send.
  waiting,
}

/// What the sync has to say for itself: a phase, when it last went
/// through, how much is waiting, and what went wrong.
class CloudStatus {
  const CloudStatus({
    this.phase = CloudPhase.never,
    this.lastSyncedAt,
    this.pending = 0,
    this.error,
  });

  final CloudPhase phase;
  final DateTime? lastSyncedAt;

  /// Changes still to send: rows written or removed.
  final int pending;

  /// The last error, in the words it came with. Null when there was none.
  final String? error;

  /// The word Settings shows beside iCloud.
  String get label => switch (phase) {
    CloudPhase.notSignedIn => 'Not signed in',
    CloudPhase.never => 'Never synced',
    CloudPhase.syncing => 'Syncing',
    CloudPhase.upToDate => 'Up to date',
    CloudPhase.waiting => 'Waiting to send',
  };

  /// The small print under it, judged at [now].
  String detail(DateTime now) => switch (phase) {
    CloudPhase.notSignedIn =>
      'Sign into iCloud in Settings to sync between devices.',
    CloudPhase.never => 'Nothing has been sent yet.',
    CloudPhase.syncing =>
      pending == 0 ? 'Checking for changes…' : 'Sending ${_changes(pending)}…',
    CloudPhase.upToDate =>
      lastSyncedAt == null
          ? 'Last synced just now.'
          : 'Last synced ${agoLabel(lastSyncedAt!, now: now)}.',
    CloudPhase.waiting =>
      '${_changes(pending)} to send. Will retry when online.',
  };

  static String _changes(int count) =>
      count == 1 ? '1 change' : '$count changes';

  CloudStatus copyWith({
    CloudPhase? phase,
    DateTime? lastSyncedAt,
    int? pending,
    String? error,
    bool clearError = false,
  }) => CloudStatus(
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    pending: pending ?? this.pending,
    error: clearError ? null : (error ?? this.error),
  );
}
