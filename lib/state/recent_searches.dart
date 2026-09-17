import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';
import 'providers.dart';

/// The last few things searched for, newest first, so one can be run again
/// with a tap. A search is remembered when it is submitted or when one of
/// its results is opened, not as it is typed.
///
/// Starts from [initialRecentSearchesProvider], which `main` binds to the
/// saved list before the first frame.
class RecentSearches extends Notifier<List<String>> {
  /// The name the list is written under in the settings store.
  static const settingKey = 'recent_searches';

  /// How many are kept. The oldest falls off the end.
  static const keep = 5;

  static Future<List<String>> load(SettingsStore store) async =>
      decode(await store.read(settingKey));

  /// The saved list, or nothing for anything unreadable.
  static List<String> decode(String? saved) {
    if (saved == null) return const [];
    try {
      final list = jsonDecode(saved);
      if (list is List) {
        return List.unmodifiable([
          for (final each in list)
            if (each is String) each,
        ]);
      }
    } on FormatException {
      // Nothing worth keeping.
    }
    return const [];
  }

  @override
  List<String> build() => ref.watch(initialRecentSearchesProvider);

  /// Puts [query] at the front, moving it there if it was already kept,
  /// case aside.
  Future<void> remember(String query) async {
    final words = query.trim();
    if (words.isEmpty) return;
    final kept = [
      words,
      for (final each in state)
        if (each.toLowerCase() != words.toLowerCase()) each,
    ];
    await _keep(kept.take(keep).toList());
  }

  Future<void> forget() => _keep(const []);

  Future<void> _keep(List<String> searches) async {
    state = List.unmodifiable(searches);
    await ref.read(settingsStoreProvider).write(settingKey, jsonEncode(state));
  }
}
