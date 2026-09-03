import 'package:flutter/material.dart';

/// The one hairline this app draws.
class BrandedDivider extends StatelessWidget {
  const BrandedDivider({super.key});

  static BorderSide sideOf(BuildContext context) => BorderSide(
    color: Theme.of(context).colorScheme.outlineVariant,
    width: 0.5,
  );

  @override
  Widget build(BuildContext context) => const Divider();
}
