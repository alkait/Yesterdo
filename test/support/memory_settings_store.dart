import 'package:remind_me/data/settings_store.dart';

/// An in-memory settings store for widget tests. Real sqflite hangs under the
/// widget tester's fake clock.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
