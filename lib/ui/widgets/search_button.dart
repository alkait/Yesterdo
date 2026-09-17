import 'package:flutter/material.dart';

import '../branded/branded.dart';
import '../search_page.dart';

/// The magnifier at the bottom right, before the gear. It opens the search
/// screen.
class SearchButton extends StatelessWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context) => BrandedIconButton(
    icon: Icons.search_rounded,
    label: 'Search',
    size: BrandedIconSize.medium,
    onTap: () => openBrandedPage<void>(context, (_) => const SearchPage()),
  );
}
