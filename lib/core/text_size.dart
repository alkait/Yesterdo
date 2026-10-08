/// How large the words are drawn, as a factor over the size the system
/// asks for. On a phone it stacks on top of the per-app size in the
/// system's settings; on a Mac, which offers no such dial for an iPad app,
/// it is the only one.
enum AppTextSize {
  small('Small', 0.9),
  standard('Default', 1.0),
  large('Large', 1.15),
  larger('Larger', 1.3),
  largest('Largest', 1.5);

  const AppTextSize(this.label, this.factor);

  /// What the chooser calls it.
  final String label;

  /// What every text size, icon and tick is multiplied by.
  final double factor;

  /// The one the app ships with.
  static const fallback = standard;

  /// The size written under this name, or the fallback for a name it does
  /// not know.
  static AppTextSize fromName(String? name) =>
      values.firstWhere((size) => size.name == name, orElse: () => fallback);
}
