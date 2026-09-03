import 'package:flutter/material.dart';

import 'brand.dart';

/// Opens the app's one kind of modal surface.
Future<T?> showBrandedSheet<T>(
  BuildContext context,
  WidgetBuilder builder,
) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  barrierColor: Colors.black.withValues(alpha: 0.28),
  builder: (sheetContext) => _BrandedSheet(child: builder(sheetContext)),
);

class _BrandedSheet extends StatelessWidget {
  const _BrandedSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    // heightFactor keeps the sheet hugging its content instead of filling the
    // screen, while the child stays centred and capped for iPad.
    child: Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Brand.maxSheetWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: child,
        ),
      ),
    ),
  );
}
