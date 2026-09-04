import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../state/providers.dart';
import 'brand.dart';

/// The app shell. The only place a theme is attached, drawn in whichever look
/// the person has chosen; the system still picks light or dark.
class BrandedApp extends ConsumerWidget {
  const BrandedApp({super.key, required this.title, required this.home});

  final String title;
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeChoiceProvider);
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(choice),
      darkTheme: AppTheme.dark(choice),
      themeAnimationDuration: Brand.quick,
      themeAnimationCurve: Brand.curve,
      home: home,
    );
  }
}
