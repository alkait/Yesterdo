import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'branded_divider.dart';

/// The top chrome: something either side, something in the middle, and a
/// hairline underneath. Flat, with no Material elevation. The sides are
/// given equal room, so the middle sits on the screen's centre line whatever
/// is or is not beside it, and a title too wide for what they leave shrinks
/// to fit rather than crowding them.
class BrandedAppBar extends StatelessWidget {
  const BrandedAppBar({
    super.key,
    this.leading,
    this.trailing,
    required this.center,
    this.onTapCenter,
  });

  final Widget? leading;
  final Widget? trailing;
  final Widget center;
  final VoidCallback? onTapCenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: _BarRow(
            leading: leading ?? const SizedBox.shrink(),
            center: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapCenter,
              // Handed a bounded width by the layout below, so anything too
              // wide for it comes down in size, keeping its proportions.
              child: FittedBox(fit: BoxFit.scaleDown, child: center),
            ),
            trailing: trailing ?? const SizedBox.shrink(),
          ),
        ),
        const BrandedDivider(),
      ],
    );
  }
}

/// The bar's own layout: the sides take what they ask for, the narrower is
/// given as much room as the wider, and the middle gets what is left, on the
/// centre line. A [Row] cannot do this, because it measures a middle that
/// does not flex before it knows what the sides need.
class _BarRow extends MultiChildRenderObjectWidget {
  _BarRow({
    required Widget leading,
    required Widget center,
    required Widget trailing,
  }) : super(children: [leading, center, trailing]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarRow();
}

class _BarParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBarRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BarParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BarParentData) child.parentData = _BarParentData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final leading = firstChild!;
    final center = childAfter(leading)!;
    final trailing = childAfter(center)!;

    // Neither side may take more than its half, so the middle always has
    // somewhere to be.
    final beside = BoxConstraints.loose(Size(width / 2, double.infinity));
    leading.layout(beside, parentUsesSize: true);
    trailing.layout(beside, parentUsesSize: true);
    final side = math.max(leading.size.width, trailing.size.width);
    center.layout(
      BoxConstraints.loose(Size(width - side * 2, double.infinity)),
      parentUsesSize: true,
    );

    final height = math.max(
      center.size.height,
      math.max(leading.size.height, trailing.size.height),
    );
    size = constraints.constrain(Size(width, height));

    void place(RenderBox child, double x) {
      (child.parentData! as _BarParentData).offset = Offset(
        x,
        (height - child.size.height) / 2,
      );
    }

    place(leading, 0);
    place(center, (width - center.size.width) / 2);
    place(trailing, width - trailing.size.width);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
