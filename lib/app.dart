import 'package:flutter/material.dart';

import 'ui/branded/branded.dart';
import 'ui/home_page.dart';

class YesterdoApp extends StatelessWidget {
  const YesterdoApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const BrandedApp(title: 'Yesterdo', home: HomePage());
}
