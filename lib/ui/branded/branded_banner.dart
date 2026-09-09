import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_button.dart';
import 'branded_text.dart';

/// A quiet word from the foot of the screen: what happened on the left, and
/// one thing to do about it on the right.
///
/// It slides up over the content rather than pushing it aside, and is drawn
/// in the same grey as a swipe button, so it reports without demanding. A
/// push sideways or downwards sends it away; anything short of that lets it
/// settle back. Up is where it came from, so it does not go that way.
class BrandedBanner extends StatefulWidget {
  const BrandedBanner({
    super.key,
    required this.message,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  /// The headline. One line, cut with an ellipsis when it is too long.
  final String message;

  /// The small print under it.
  final String detail;

  final String actionLabel;
  final VoidCallback onAction;

  /// Called once it has gone, so whoever put it up can forget it.
  final VoidCallback onDismiss;

  @override
  State<BrandedBanner> createState() => _BrandedBannerState();
}

class _BrandedBannerState extends State<BrandedBanner>
    with TickerProviderStateMixin {
  /// The slide up as it arrives, as a fraction of its own height still to go.
  late final AnimationController _arrival =
      AnimationController(vsync: this, duration: Brand.quick)..forward();

  /// Carries it back into place, or the rest of the way out.
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: Brand.quick,
  );

  Animation<Offset>? _glide;
  Offset _drag = Offset.zero;

  /// Whether the glide in hand is the one that takes it away for good.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _release.addStatusListener((status) {
      if (status == AnimationStatus.completed && _leaving) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _arrival.dispose();
    _release.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _release.stop();
    setState(() {
      _drag = Offset(
        _drag.dx + details.delta.dx,
        // Downwards only: up is where it came from.
        math.max(0, _drag.dy + details.delta.dy),
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final thrown = details.velocity.pixelsPerSecond;
    final flung = thrown.distance > Brand.flingVelocity;
    if (!flung && _drag.distance < Brand.swipeDistance) return _glideTo(zero);

    // Whichever way it was going when it was let go of.
    final way = flung ? thrown : _drag;
    final sideways = way.dx.abs() >= way.dy.abs();
    if (!sideways && way.dy <= 0) return _glideTo(zero);

    final size = MediaQuery.sizeOf(context);
    _leaving = true;
    _glideTo(
      sideways
          ? Offset(way.dx.isNegative ? -size.width : size.width, _drag.dy)
          : Offset(_drag.dx, size.height),
    );
  }

  static const zero = Offset.zero;

  void _glideTo(Offset target) {
    _glide =
        Tween<Offset>(begin: _drag, end: target).animate(
          CurvedAnimation(parent: _release, curve: Brand.curve),
        )..addListener(() {
          setState(() => _drag = _glide!.value);
        });
    _release.forward(from: 0);
  }

  /// Fades as it is pushed away, and is gone by the time it has travelled
  /// far enough to be let go of.
  double get _opacity => (1 - _drag.distance / Brand.noticeFade).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanUpdate: _onDragUpdate,
      onPanEnd: _onDragEnd,
      child: Transform.translate(
        offset: _drag,
        child: Opacity(
          opacity: _opacity,
          child: AnimatedBuilder(
            animation: _arrival,
            builder: (context, child) => FractionalTranslation(
              translation: Offset(0, 1 - _arrival.value),
              child: child,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Brand.maxContentWidth,
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                    Brand.gutter,
                    0,
                    Brand.gutter,
                    Brand.cardGap / 2,
                  ),
                  padding: const EdgeInsets.only(
                    left: Brand.cardPaddingH,
                    right: 4,
                  ),
                  constraints: const BoxConstraints(
                    minHeight: Brand.rowMinHeight,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Brand.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.onSurface.withValues(
                          alpha: Brand.shadowAlpha,
                        ),
                        blurRadius: Brand.shadowBlur,
                        offset: Brand.shadowOffset,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandedText(widget.message, maxLines: 1),
                            BrandedText(
                              widget.detail,
                              role: BrandedTextRole.caption,
                              tone: BrandedTone.muted,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Brand.gap),
                      BrandedTextButton(
                        label: widget.actionLabel,
                        tone: BrandedTone.accent,
                        onTap: widget.onAction,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
