import 'dart:math';

import 'rich/task_body.dart';

/// What a row is called across devices. Local row ids are a device's own;
/// a uid goes with the row wherever it is sent.
String newUid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// The uid a rule's showing on [day] has wherever it is written down, so
/// two devices that both act on the same showing write the same row rather
/// than one each.
String occurrenceUid(String ruleUid, int day) => '$ruleUid-$day';

/// What kind of row a record is.
enum SyncKind { todo, rule }

/// One row as it crosses between devices: its uid, when it was last
/// written, and its columns, less the ids that are the device's own.
/// Pictures are named by the body, so the device can send and fetch them
/// beside it.
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.uid,
    required this.updatedAt,
    required this.fields,
  });

  factory SyncRecord.fromJson(Map<String, Object?> json) => SyncRecord(
    kind: SyncKind.values.byName(json['kind']! as String),
    uid: json['uid']! as String,
    updatedAt: json['updatedAt']! as int,
    fields: Map<String, Object?>.from(json['fields']! as Map),
  );

  final SyncKind kind;
  final String uid;

  /// Epoch milliseconds of the write that made the row what it is.
  final int updatedAt;

  /// The row's columns, keyed as the table keys them. A todo names its
  /// rule by `recurrence_uid`, never by a local id.
  final Map<String, Object?> fields;

  /// The pictures the words refer to, by file name.
  List<String> get images => switch (fields['body']) {
    final String json => TaskBody.decode(json).images,
    _ => const [],
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'uid': uid,
    'updatedAt': updatedAt,
    'fields': fields,
    'images': images,
  };
}

/// A set of rows going one way: the ones written, and the uids of the ones
/// gone.
class SyncBatch {
  const SyncBatch({
    this.changed = const [],
    this.deleted = const [],
    this.token,
    this.reset = false,
  });

  factory SyncBatch.fromJson(Map<String, Object?> json) => SyncBatch(
    changed: [
      for (final each in (json['changed'] as List?) ?? const [])
        SyncRecord.fromJson(Map<String, Object?>.from(each as Map)),
    ],
    deleted: [
      for (final each in (json['deleted'] as List?) ?? const []) each as String,
    ],
    token: json['token'] as String?,
    reset: json['reset'] as bool? ?? false,
  );

  final List<SyncRecord> changed;
  final List<String> deleted;

  /// Where the other side's reading got to, to be handed back next time so
  /// only what came after is sent. Null when there is nothing to remember.
  final String? token;

  /// The other side has nothing of ours any more, as when the iCloud data
  /// was cleared, so everything local is to be sent again.
  final bool reset;

  bool get isEmpty => changed.isEmpty && deleted.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'changed': [for (final each in changed) each.toJson()],
    'deleted': deleted,
    if (token != null) 'token': token,
  };
}

/// Rules ahead of todos, so whoever takes the records has a rule before
/// its showings. Order within a kind is kept.
List<SyncRecord> rulesFirst(List<SyncRecord> records) => <SyncRecord>[
  for (final each in records)
    if (each.kind == SyncKind.rule) each,
  for (final each in records)
    if (each.kind == SyncKind.todo) each,
];

/// What is held locally for a uid, when deciding whether an incoming row
/// is taken.
class LocalState {
  const LocalState({
    required this.updatedAt,
    required this.pending,
    required this.deleted,
  });

  /// Nothing held: a row never seen here.
  static const none = LocalState(
    updatedAt: null,
    pending: false,
    deleted: false,
  );

  final int? updatedAt;

  /// Written here since the last send.
  final bool pending;

  /// Removed here since the last send, and still to be told.
  final bool deleted;
}

/// Whether an incoming row is taken over what is held locally. The latest
/// write wins, and a removal beats an edit: a row removed here stays
/// removed whatever comes in for it, and one removed elsewhere goes
/// whatever was done to it here. A row not written here since the last
/// send is always taken, so both sides end up holding the same thing.
bool takesIncoming(LocalState local, {required int updatedAt}) {
  if (local.deleted) return false;
  if (!local.pending) return true;
  return updatedAt > (local.updatedAt ?? 0);
}
