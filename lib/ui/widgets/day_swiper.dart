import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../branded/branded.dart';

/// Turns the page a day at a time: a swipe left goes to tomorrow, right to
/// yesterday. A quick flick counts, and so does a slow pull far enough,
/// since a finger that stops before lifting has no speed left to measure.
/// A card's own sideways swipe still wins on the card itself, being the
/// nearer of the two.
class DaySwiper extends ConsumerStatefulWidget {
  const DaySwiper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DaySwiper> createState() => _DaySwiperState();
}

class _DaySwiperState extends ConsumerState<DaySwiper> {
  double _pulled = 0;

  void _onEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final flicked = velocity.abs() >= Brand.flingVelocity;
    final pulled = _pulled.abs() >= Brand.swipeDistance;
    final leftwards = flicked ? velocity < 0 : _pulled < 0;
    _pulled = 0;
    if (!flicked && !pulled) return;
    ref.read(selectedDayProvider.notifier).shift(leftwards ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _pulled = 0,
    onHorizontalDragUpdate: (details) => _pulled += details.delta.dx,
    onHorizontalDragEnd: _onEnd,
    onHorizontalDragCancel: () => _pulled = 0,
    child: widget.child,
  );
}
