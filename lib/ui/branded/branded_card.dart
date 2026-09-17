import 'package:flutter/material.dart';

import 'brand.dart';

/// One item in a list, drawn as a bordered card so the eye separates it from
/// its neighbours without a rule between them.
///
/// A [calling] card breathes: its border and face lean gently into the
/// accent and back, without end, until someone answers it. With animations
/// turned off it holds the leaning colour still instead.
///
/// A [spotlit] card takes the same breath a couple of times and settles, to
/// point itself out once, as when a search found it. It is a nudge, not a
/// state: only the change to [spotlit] starts it, and it runs its course
/// whatever the flag does after.
class BrandedCard extends StatefulWidget {
  const BrandedCard({
    super.key,
    this.leading,
    required this.child,
    this.trailing,
    this.onTap,
    this.recessed = false,
    this.calling = false,
    this.spotlit = false,
  });

  final Widget? leading;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Settles the card into the page, for content that is done with: the
  /// raised surface colour, and no shadow to lift it.
  final bool recessed;

  /// Asks for attention, continuously, until answered.
  final bool calling;

  /// Points itself out once, on becoming true.
  final bool spotlit;

  @override
  State<BrandedCard> createState() => _BrandedCardState();
}

class _BrandedCardState extends State<BrandedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: Brand.breath,
  );
  late final Animation<double> _lean = CurvedAnimation(
    parent: _breath,
    curve: Brand.breathCurve,
  );

  /// Whether a spotlight is running its course, so a settle in the
  /// meantime leaves it be.
  bool _spotlighting = false;

  /// Whether the motion setting has been read, which initState is too
  /// early for.
  bool _ready = false;

  @override
  void didUpdateWidget(BrandedCard old) {
    super.didUpdateWidget(old);
    if (old.calling != widget.calling) _settle();
    if (!old.spotlit && widget.spotlit) _spotlight();
  }

  /// Also the first chance to read the motion setting, which initState is
  /// too early for.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settle();
    if (!_ready) {
      _ready = true;
      if (widget.spotlit) _spotlight();
    }
  }

  /// A few breaths, then still. A calling card is breathing already, and
  /// reduced motion is left in peace.
  void _spotlight() {
    if (widget.calling || MediaQuery.disableAnimationsOf(context)) return;
    _spotlighting = true;
    _breath.value = 0;
    // A count is of half-breaths: in is one, out is the next.
    _breath.repeat(reverse: true, count: Brand.spotlightBreaths * 2).then((_) {
      _spotlighting = false;
      if (mounted && !widget.calling) _breath.value = 0;
    });
  }

  /// Breathes while calling, holds still otherwise. Reduced motion holds the
  /// card at the top of a breath so it is still seen to be calling.
  void _settle() {
    if (!widget.calling) {
      if (_spotlighting) return;
      _breath.stop();
      _breath.value = 0;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _spotlighting = false;
      _breath.stop();
      _breath.value = 1;
    } else if (!_breath.isAnimating || _spotlighting) {
      _spotlighting = false;
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final face = widget.recessed
        ? scheme.surfaceContainerHighest
        : scheme.surface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _lean,
        builder: (context, child) => Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Brand.gutter,
            vertical: Brand.cardGap / 2,
          ),
          constraints: const BoxConstraints(minHeight: Brand.cardMinHeight),
          decoration: BoxDecoration(
            color: Color.lerp(
              face,
              scheme.primary,
              _lean.value * Brand.callingTint,
            ),
            borderRadius: BorderRadius.circular(Brand.cardRadius),
            border: Border.all(
              color: Color.lerp(
                scheme.outlineVariant,
                scheme.primary,
                _lean.value,
              )!,
              width: Brand.borderWidth,
            ),
            boxShadow: widget.recessed
                ? null
                : [
                    BoxShadow(
                      color: scheme.onSurface.withValues(
                        alpha: Brand.shadowAlpha,
                      ),
                      blurRadius: Brand.shadowBlur,
                      offset: Brand.shadowOffset,
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Brand.cardPaddingH,
            vertical: Brand.cardPaddingV,
          ),
          child: child,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: Brand.gap),
            ],
            Expanded(child: widget.child),
            if (widget.trailing != null) ...[
              const SizedBox(width: Brand.gap),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
