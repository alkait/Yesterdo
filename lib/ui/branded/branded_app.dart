import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../state/providers.dart';
import 'brand.dart';

/// The app shell. The only place a theme is attached, drawn in whichever look
/// the person has chosen; the system still picks light or dark. The only
/// place the text size is applied, too: the chosen factor goes over the
/// size the system asks for, and every screen reads the result through the
/// `MediaQuery`, so words, icons and ticks grow together and rows grow to
/// fit them, as they do on a phone.
class BrandedApp extends ConsumerWidget {
  const BrandedApp({super.key, required this.title, required this.home});

  final String title;
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeChoiceProvider);
    final size = ref.watch(textSizeProvider);
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(choice),
      darkTheme: AppTheme.dark(choice),
      themeAnimationDuration: Brand.quick,
      themeAnimationCurve: Brand.curve,
      builder: (context, child) {
        final query = MediaQuery.of(context);
        return MediaQuery(
          data: query.copyWith(
            textScaler: TextScaler.linear(
              query.textScaler.scale(1) * size.factor,
            ),
          ),
          child: child!,
        );
      },
      home: home,
    );
  }
}
