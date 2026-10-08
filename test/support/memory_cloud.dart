import 'package:remind_me/data/sync_record.dart';
import 'package:remind_me/sync/cloud_transport.dart';

/// A cloud for tests: records by uid, and a log of every write in order,
/// so a pull from a token hands back what came after it. Several
/// transports share one, the way several devices share an iCloud account.
class MemoryCloud {
  final Map<String, SyncRecord> records = <String, SyncRecord>{};

  /// Every write, as the uid written or removed, in order. A token is a
  /// place in this list.
  final List<({String uid, bool deleted})> log =
      <({String uid, bool deleted})>[];

  /// Transports to be told when another one has written.
  final List<MemoryCloudTransport> _listening = <MemoryCloudTransport>[];

  /// Whether the records have been cleared out from under every device, as
  /// when the iCloud data is deleted.
  bool wiped = false;

  /// Empties the cloud, so the next pull from any device says `reset`.
  void wipe() {
    records.clear();
    log.clear();
    wiped = true;
  }

  SyncBatch since(String? token) {
    if (wiped) {
      wiped = false;
      return const SyncBatch(reset: true);
    }
    final from = token == null ? 0 : int.parse(token);
    final changed = <String, SyncRecord>{};
    final deleted = <String>{};
    for (final entry in log.sublist(from)) {
      if (entry.deleted) {
        changed.remove(entry.uid);
        deleted.add(entry.uid);
      } else if (records[entry.uid] != null) {
        deleted.remove(entry.uid);
        changed[entry.uid] = records[entry.uid]!;
      }
    }
    return SyncBatch(
      changed: changed.values.toList(),
      deleted: deleted.toList(),
      token: '${log.length}',
    );
  }

  void take(SyncBatch batch, {MemoryCloudTransport? from}) {
    for (final record in batch.changed) {
      records[record.uid] = record;
      log.add((uid: record.uid, deleted: false));
    }
    for (final uid in batch.deleted) {
      records.remove(uid);
      log.add((uid: uid, deleted: true));
    }
    if (batch.isEmpty) return;
    for (final other in _listening) {
      if (other != from) other.changed?.call();
    }
  }
}

/// One device's way to a [MemoryCloud].
class MemoryCloudTransport implements CloudTransport {
  MemoryCloudTransport(this.cloud, {this.signedIn = true}) {
    cloud._listening.add(this);
  }

  final MemoryCloud cloud;

  /// Whether the device is signed into iCloud.
  bool signedIn;

  /// Whether the next push is to fail, as when the network is away.
  bool failNextPush = false;

  int pushes = 0;
  int pulls = 0;

  void Function()? changed;

  @override
  Future<bool> available() => Future.value(signedIn);

  @override
  Future<SyncBatch> pull(String? token) {
    pulls++;
    return Future.value(cloud.since(token));
  }

  @override
  Future<void> push(SyncBatch batch) {
    pushes++;
    if (failNextPush) {
      failNextPush = false;
      return Future.error(StateError('no network'));
    }
    cloud.take(batch, from: this);
    return Future.value();
  }

  @override
  void onChange(void Function() handler) => changed = handler;
}
