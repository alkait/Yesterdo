import 'package:flutter/widgets.dart';

/// Asks for the keyboard only once a screen has finished sliding in.
/// Raised during the transition, it fights the slide and the whole thing
/// judders. Armed after the first frame, since during the first build the
/// route's animation has not yet been started.
class ArrivalFocus {
  ArrivalFocus(this.onArrived);

  /// Raises the keyboard. Called at once when there is no slide to wait
  /// for.
  final VoidCallback onArrived;

  Animation<double>? _arrival;

  /// Call after the first frame, from a mounted [context].
  void arm(BuildContext context) {
    final arrival = ModalRoute.of(context)?.animation;
    if (arrival == null || arrival.isCompleted) {
      onArrived();
      return;
    }
    _arrival = arrival..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    dispose();
    onArrived();
  }

  void dispose() {
    _arrival?.removeStatusListener(_onStatus);
    _arrival = null;
  }
}
