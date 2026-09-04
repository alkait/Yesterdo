import 'dart:io';

import '../data/todo_store.dart';

/// Clears out pictures no task refers to any more. Run once at launch,
/// after the first frame, rather than on every delete: a picture may be
/// shared between a rule and its written-down showings, and only a sweep
/// over everything can tell when it is truly unwanted.
class ImageSweep {
  const ImageSweep(this._store, this._directory);

  final TodoStore _store;
  final String _directory;

  /// The files removed.
  Future<List<String>> run() async {
    final folder = Directory(_directory);
    if (!folder.existsSync()) return const [];
    final wanted = await _store.allImages();
    final gone = <String>[];
    for (final entity in folder.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (wanted.contains(name)) continue;
      entity.deleteSync();
      gone.add(name);
    }
    return gone;
  }
}
