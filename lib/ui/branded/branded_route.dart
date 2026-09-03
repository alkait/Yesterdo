import 'package:flutter/material.dart';

/// Opens a full screen. The one place a page transition is chosen, so every
/// push in the app animates the same way.
Future<T?> openBrandedPage<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: builder));
