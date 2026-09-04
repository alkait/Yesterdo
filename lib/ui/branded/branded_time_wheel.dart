import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_text.dart';

/// The wheel a time of day is chosen on. Reports minutes after midnight.
class BrandedTimeWheel extends StatelessWidget {
  const BrandedTimeWheel({
    super.key,
    required this.minute,
    required this.onChanged,
  });

  /// Minutes after midnight the wheel opens on. Rounded to the wheel's own
  /// step, which the picker insists on.
  final int minute;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final rounded =
        (minute / Brand.wheelMinuteStep).round() * Brand.wheelMinuteStep;
    final opening = DateTime(2000, 1, 1, rounded ~/ 60, rounded % 60);

    return SizedBox(
      height: Brand.wheelHeight,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: Theme.of(context).colorScheme.onSurface,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: BrandedText.styleFor(BrandedTextRole.wheel)
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: opening,
          minuteInterval: Brand.wheelMinuteStep,
          use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          onDateTimeChanged: (time) => onChanged(time.hour * 60 + time.minute),
        ),
      ),
    );
  }
}
