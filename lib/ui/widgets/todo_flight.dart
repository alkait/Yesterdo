import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../branded/branded.dart';

/// The one item whose place changed between two orders, if taking it out
/// of both leaves them the same. Null for any other kind of change. What
/// sets a flight going, for a card on the day and for an item on a
/// checklist alike.
({String key, int from, int to})? singleMove(
  List<String> before,
  List<String> after,
) {
  if (before.length != after.length) return null;
  for (var at = 0; at < before.length; at++) {
    if (before[at] == after[at]) continue;
    for (final key in [before[at], after[at]]) {
      final to = after.indexOf(key);
      final from = before.indexOf(key);
      // A key on one side only is an item replaced, not moved.
      if (to == -1 || from == -1) continue;
      final restBefore = [...before]..removeAt(from);
      final restAfter = [...after]..removeAt(to);
      if (_sameOrder(restBefore, restAfter)) {
        return (key: key, from: from, to: to);
      }
    }
    return null;
  }
  return null;
}

bool _sameOrder(List<String> a, List<String> b) {
  for (var at = 0; at < a.length; at++) {
    if (a[at] != b[at]) return false;
  }
  return true;
}

/// A card's journey from where it was to where the order now puts it.
///
/// The list shows the new order at once, but with the card's new slot
/// starting closed and a spacer where it used to be, so the cards between
/// hold still. Over the flight the spacer closes, the slot opens and a copy
/// of the card travels over the list from the one to the other, swelling a
/// touch on the way as a lifted card does. When it lands the copy goes and
/// the real card is shown in its place.
class TodoFlight {
  TodoFlight({
    required this.key,
    required this.from,
    required this.card,
    required TickerProvider vsync,
  }) : _controller = AnimationController(vsync: vsync, duration: Brand.flight);

  /// The [Todo.key] of the card on the move.
  final String key;

  /// Where the card was, in global coordinates, measured before the new
  /// order was laid out.
  final Rect from;

  /// The card as it now stands, drawn once more to make the journey.
  final Widget card;

  final AnimationController _controller;
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Brand.flightCurve,
  );
  final _link = LayerLink();
  final _slotKey = GlobalKey();
  OverlayEntry? _entry;

  /// How far above or below its slot the card starts.
  double _delta = 0;

  /// The card's new place in the list: opens over the flight, and is where
  /// the travelling copy lands. The real card sits inside, unseen until it
  /// has.
  Widget slot(Widget child) => KeyedSubtree(
    key: ValueKey('flight-slot-$key'),
    child: CompositedTransformTarget(
      link: _link,
      child: SizeTransition(
        key: _slotKey,
        sizeFactor: _t,
        alignment: Alignment.topCenter,
        child: IgnorePointer(child: Opacity(opacity: 0, child: child)),
      ),
    ),
  );

  /// Where the card used to be: closes over the flight.
  Widget spacer() => SizeTransition(
    key: ValueKey('flight-spacer-$key'),
    sizeFactor: ReverseAnimation(_t),
    alignment: Alignment.topCenter,
    child: SizedBox(height: from.height),
  );

  /// Once the new order has been laid out: measures where the slot is, puts
  /// the copy up over the list and sets it going. False when the slot is
  /// off the screen, in which case there is nothing to see and the list
  /// may as well show the new order plainly.
  bool launch(OverlayState overlay, VoidCallback onLanded) {
    final box = _slotKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    _delta = from.top - box.localToGlobal(Offset.zero).dy;
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: from.width,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, child) => CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, _delta * (1 - _t.value)),
              child: Transform.scale(
                scale: 1 + Brand.flightLift * math.sin(math.pi * _t.value),
                child: child,
              ),
            ),
            child: card,
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    _controller.forward().whenCompleteOrCancel(onLanded);
    return true;
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
    _controller.dispose();
  }
}
