import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';
import 'branded_text.dart';

/// One button revealed by a swipe: an icon, or two short words stacked
/// where the icon would be, for a meaning no icon carries.
class BrandedSwipeAction {
  const BrandedSwipeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = BrandedTone.primary,
  }) : words = null;

  const BrandedSwipeAction.words(
    this.words, {
    required this.label,
    required this.onTap,
    this.tone = BrandedTone.primary,
  }) : icon = null;

  final IconData? icon;

  /// Drawn one above the other in place of an icon, such as `('NOT',
  /// 'TODAY')`.
  final (String, String)? words;

  /// Read aloud by VoiceOver. The button alone says nothing.
  final String label;

  final VoidCallback onTap;
  final BrandedTone tone;
}

/// Tracks which row in a list is currently swiped open, so opening one closes
/// the last. Owned by the list, handed to every row.
class BrandedSwipeGroup extends ValueNotifier<Object?> {
  BrandedSwipeGroup() : super(null);
}

/// Slides a row aside to uncover buttons. Nothing happens until one of those
/// buttons is tapped, so a swipe can always be taken back.
class BrandedSwipeActions extends StatefulWidget {
  const BrandedSwipeActions({
    super.key,
    required this.group,
    required this.id,
    required this.child,
    this.leading = const <BrandedSwipeAction>[],
    this.trailing = const <BrandedSwipeAction>[],
  });

  final BrandedSwipeGroup group;

  /// Identifies this row within its group.
  final Object id;

  final Widget child;

  /// Uncovered by swiping right, drawn from the leading edge inwards.
  final List<BrandedSwipeAction> leading;

  /// Uncovered by swiping left, drawn from the trailing edge inwards.
  final List<BrandedSwipeAction> trailing;

  @override
  State<BrandedSwipeActions> createState() => _BrandedSwipeActionsState();
}

class _BrandedSwipeActionsState extends State<BrandedSwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Brand.quick,
  );
  Animation<double>? _slide;
  double _offset = 0;

  static double _extentFor(int count) =>
      count * (Brand.swipeActionWidth + Brand.swipeActionGap);

  double get _leadingExtent => _extentFor(widget.leading.length);
  double get _trailingExtent => _extentFor(widget.trailing.length);
  bool get _isOpen => _offset != 0;

  @override
  void initState() {
    super.initState();
    widget.group.addListener(_onGroupChanged);
  }

  @override
  void dispose() {
    widget.group.removeListener(_onGroupChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onGroupChanged() {
    if (widget.group.value != widget.id && _isOpen) _animateTo(0);
  }

  void _animateTo(double target) {
    _slide = Tween<double>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Brand.curve),
    )..addListener(() => setState(() => _offset = _slide!.value));
    _controller.forward(from: 0);
    if (target == 0 && widget.group.value == widget.id) {
      widget.group.value = null;
    }
  }

  void _close() => _animateTo(0);

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(
        -_trailingExtent,
        _leadingExtent,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final extent = _offset > 0 ? _leadingExtent : _trailingExtent;
    if (extent == 0) return _animateTo(0);

    // A flick decides on its own; otherwise the halfway mark does.
    final opening = velocity.abs() > 350
        ? (velocity > 0) == (_offset > 0)
        : _offset.abs() > extent / 2;

    if (!opening) return _animateTo(0);
    widget.group.value = widget.id;
    _animateTo(_offset > 0 ? _leadingExtent : -_trailingExtent);
  }

  void _run(BrandedSwipeAction action) {
    _close();
    action.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final showLeading = _offset > 0;
    final actions = showLeading ? widget.leading : widget.trailing;

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          if (_isOpen)
            Positioned.fill(
              child: _ActionStrip(
                actions: actions,
                alignment: showLeading
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                onRun: _run,
              ),
            ),
          // The card is squeezed rather than slid, so it keeps both of its
          // rounded ends on screen instead of running off the edge.
          Padding(
            padding: EdgeInsets.only(
              left: _offset > 0 ? _offset : 0,
              right: _offset < 0 ? -_offset : 0,
            ),
            child: widget.child,
          ),
          // While open, a tap anywhere on the card puts it back rather than
          // reaching the card's own gestures.
          if (_isOpen)
            Positioned.fill(
              left: _offset > 0 ? _offset : 0,
              right: _offset < 0 ? -_offset : 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.actions,
    required this.alignment,
    required this.onRun,
  });

  final List<BrandedSwipeAction> actions;
  final Alignment alignment;
  final void Function(BrandedSwipeAction) onRun;

  @override
  Widget build(BuildContext context) => Padding(
    // Matches the card's own margin, so buttons line up with its edges.
    padding: const EdgeInsets.symmetric(
      horizontal: Brand.gutter,
      vertical: Brand.cardGap / 2,
    ),
    child: Align(
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, action) in actions.indexed) ...[
            if (index > 0) const SizedBox(width: Brand.swipeActionGap),
            _ActionButton(action: action, onRun: onRun),
          ],
        ],
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onRun});

  final BrandedSwipeAction action;
  final void Function(BrandedSwipeAction) onRun;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: action.label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onRun(action),
      child: Container(
        width: Brand.swipeActionWidth,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Brand.cardRadius),
        ),
        child: switch (action.words) {
          null => BrandedIcon(action.icon!, tone: action.tone),
          (final top, final bottom) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandedText(top, role: BrandedTextRole.glyph, tone: action.tone),
              BrandedText(
                bottom,
                role: BrandedTextRole.glyph,
                tone: action.tone,
              ),
            ],
          ),
        },
      ),
    ),
  );
}
