import 'package:flutter/material.dart';

import 'brand.dart';

/// The page frame: brand surface, safe area, and the width cap that keeps an
/// iPad readable. Every screen is built on this.
class BrandedScaffold extends StatelessWidget {
  const BrandedScaffold({super.key, required this.children});

  /// Laid out top to bottom. Wrap the one that should stretch in [Expanded].
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Brand.maxContentWidth),
          child: Column(children: children),
        ),
      ),
    ),
  );
}
