/// Small named values that outlive a launch, such as the chosen look. One
/// implementation ships with the app; tests supply their own.
abstract class SettingsStore {
  /// The value written under [key], or null if nothing has been.
  Future<String?> read(String key);

  /// Writes [value] under [key], replacing what was there.
  Future<void> write(String key, String value);
}
