/// What marking a task done sounds like: one of the short sounds shipped in
/// the app bundle.
enum DoneSound {
  /// "UI Completed Status Alert Notification" by Headphaze on Freesound,
  /// CC BY 4.0, credited in About.
  complete('Complete', 'done.caf'),

  /// "New Notification 07" by Universfield on Pixabay, under the Pixabay
  /// Content Licence.
  notify('Notify', 'notify.caf'),

  /// A short pop and swish of the author's own.
  pop('Pop', 'pop.caf');

  const DoneSound(this.label, this.file);

  /// What the chooser calls it.
  final String label;

  /// The bundled file.
  final String file;

  /// The one the app ships with.
  static const fallback = complete;

  /// The sound written under this name, or the fallback for a name it does
  /// not know.
  static DoneSound fromName(String? name) =>
      values.firstWhere((sound) => sound.name == name, orElse: () => fallback);
}
