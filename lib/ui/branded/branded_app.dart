import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// The app shell. The only place a theme is attached.
class BrandedApp extends StatelessWidget {
  const BrandedApp({super.key, required this.title, required this.home});

  final String title;
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: title,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: home,
  );
}
