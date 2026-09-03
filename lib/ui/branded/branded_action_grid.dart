import 'package:flutter/material.dart';

import 'brand.dart';

/// Lays actions out in even rows. Rows that come up short keep their columns,
/// so tiles never stretch when a new action is added later.
class BrandedActionGrid extends StatelessWidget {
  const BrandedActionGrid({
    super.key,
    required this.children,
    this.columns = 3,
  });

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var start = 0; start < children.length; start += columns) {
      final slice = children.sublist(
        start,
        (start + columns).clamp(0, children.length),
      );
      if (rows.isNotEmpty) rows.add(const SizedBox(height: Brand.tileGap));
      rows.add(
        Row(
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) const SizedBox(width: Brand.tileGap),
              Expanded(
                child: column < slice.length
                    ? slice[column]
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
