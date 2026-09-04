/// What a reminder sounds like. The system's own sound, or one of the short
/// tones shipped in the app bundle.
enum ReminderSound {
  system('Default', null),
  chime('Chime', 'chime.caf'),
  bell('Bell', 'bell.caf'),
  glass('Glass', 'glass.caf'),
  marimba('Marimba', 'marimba.caf'),
  harp('Harp', 'harp.caf'),
  ripple('Ripple', 'ripple.caf'),
  drop('Drop', 'drop.caf'),
  pulse('Pulse', 'pulse.caf'),
  alert('Alert', 'alert.caf');

  const ReminderSound(this.label, this.file);

  /// What the chooser calls it.
  final String label;

  /// The bundled file, or null for the system's own sound.
  final String? file;

  /// The sound written under this name, or the system's for a name it does
  /// not know, so a stale value never leaves a reminder silent.
  static ReminderSound fromName(String? name) => values.firstWhere(
    (sound) => sound.name == name,
    orElse: () => ReminderSound.system,
  );
}
