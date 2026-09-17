import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A task to be pointed out on its day: raised by a search result being
/// opened, and answered by the list giving the card its spotlight once it
/// is on screen.
class Spotlight {
  const Spotlight({required this.day, required this.key});

  final int day;

  /// The task's [Todo.key].
  final String key;
}

class Spotlights extends Notifier<Spotlight?> {
  @override
  Spotlight? build() => null;

  void raise(int day, String key) => state = Spotlight(day: day, key: key);

  void clear() => state = null;
}
