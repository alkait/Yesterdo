import 'package:flutter/material.dart';

import 'brand.dart';

/// One item in a list, drawn as a bordered card so the eye separates it from
/// its neighbours without a rule between them.
///
/// A [calling] card breathes: its border and face lean gently into the
/// accent and back, without end, until someone answers it. With animations
/// turned off it holds the leaning colour still instead.
class BrandedCard extends StatefulWidget {
  const BrandedCard({
    super.key,
    this.leading,
    required this.child,
    this.trailing,
    this.onTap,
    this.recessed = false,
    this.calling = false,
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

  @override
  void didUpdateWidget(BrandedCard old) {
    super.didUpdateWidget(old);
    if (old.calling != widget.calling) _settle();
  }

  /// Also the first chance to read the motion setting, which initState is
  /// too early for.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settle();
  }

  /// Breathes while calling, holds still otherwise. Reduced motion holds the
  /// card at the top of a breath so it is still seen to be calling.
  void _settle() {
    if (!widget.calling) {
      _breath.stop();
      _breath.value = 0;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
      _breath.value = 1;
    } else if (!_breath.isAnimating) {
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
