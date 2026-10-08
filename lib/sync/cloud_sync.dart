import 'dart:async';

import '../data/sync_record.dart';
import '../data/todo_store.dart';
import 'cloud_status.dart';
import 'cloud_transport.dart';

/// Keeps the store and the cloud matching. Run after every write, on
/// launch, on return to the front, and when the cloud says another device
/// has written. Pulls first and pushes after, so what is pushed has
/// already been judged against what the other side had.
///
/// Never awaited by the interface: a write is done when the store has it,
/// and the cloud catches up behind. Runs one at a time; a nudge during a
/// run is answered by another run straight after it.
class CloudSync {
  CloudSync(
    this._store,
    this._transport, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock; // ignore: prefer_initializing_formals

  final TodoStore _store;
  final CloudTransport _transport;
  final DateTime Function() _clock;

  /// Told when a pull has changed the store, so the day can be read again.
  void Function()? onPulled;

  /// Told where the sync stands, every time that changes.
  void Function(CloudStatus)? onStatus;

  /// Where the sync stands.
  CloudStatus status = const CloudStatus();

  /// What went wrong last time. Null when the last run went through.
  Object? get lastError => _lastError;
  Object? _lastError;

  bool _running = false;
  bool _again = false;

  /// Asks for a run. Comes back at once; the run goes on behind.
  void nudge() {
    if (_running) {
      _again = true;
      return;
    }
    unawaited(_runUntilQuiet());
  }

  /// Runs once and waits for it, for a launch or a test.
  Future<void> refresh() async {
    if (_running) {
      _again = true;
      return;
    }
    await _runUntilQuiet();
  }

  Future<void> _runUntilQuiet() async {
    _running = true;
    try {
      do {
        _again = false;
        await _runOnce();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _runOnce() async {
    try {
      if (!await _transport.available()) {
        _tell(status.copyWith(phase: CloudPhase.notSignedIn, clearError: true));
        return;
      }
      _tell(status.copyWith(phase: CloudPhase.syncing, pending: 0));
      final incoming = await _transport.pull(await _store.syncToken());
      if (incoming.reset) await _store.markAllPending();
      final changed = await _store.applyRemote(incoming);
      await _store.setSyncToken(incoming.token);
      if (changed) onPulled?.call();

      final outgoing = await _store.pendingChanges();
      if (!outgoing.isEmpty) {
        _tell(status.copyWith(pending: _count(outgoing)));
        await _transport.push(outgoing);
        await _store.clearPending(outgoing);
      }
      _lastError = null;
      _tell(CloudStatus(phase: CloudPhase.upToDate, lastSyncedAt: _clock()));
    } catch (error) {
      // Kept to be tried again at the next nudge; nothing is lost, since
      // the log still holds what was not sent.
      _lastError = error;
      _tell(
        status.copyWith(
          phase: CloudPhase.waiting,
          pending: _count(await _store.pendingChanges()),
          error: '$error',
        ),
      );
    }
  }

  static int _count(SyncBatch batch) =>
      batch.changed.length + batch.deleted.length;

  void _tell(CloudStatus next) {
    status = next;
    onStatus?.call(next);
  }
}
