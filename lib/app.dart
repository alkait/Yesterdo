import 'package:flutter/material.dart';

import 'ui/branded/branded.dart';
import 'ui/home_page.dart';

class RemindMeApp extends StatelessWidget {
  const RemindMeApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const BrandedApp(title: 'RemindMe', home: HomePage());
}
