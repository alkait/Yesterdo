import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_labels.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';
import 'month_picker_sheet.dart';

/// Top bar: the day, centred, with a step arrow either side. Tapping the
/// date opens the month grid. Told which day it is for, so that while a day
/// slides out it keeps showing its own date rather than the new one.
class DateHeader extends ConsumerWidget {
  const DateHeader({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.read(selectedDayProvider.notifier);

    return BrandedAppBar(
      leading: BrandedIconButton(
        icon: Icons.chevron_left_rounded,
        label: 'Previous day',
        onTap: () => day.shift(-1),
      ),
      trailing: BrandedIconButton(
        icon: Icons.chevron_right_rounded,
        label: 'Next day',
        onTap: () => day.shift(1),
      ),
      onTapCenter: () => showMonthPickerSheet(context, ref),
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandedText(
            dayHeadline(date),
            role: BrandedTextRole.display,
            align: TextAlign.center,
          ),
          const SizedBox(height: 2),
          BrandedText(
            longDate(date),
            role: BrandedTextRole.caption,
            tone: BrandedTone.muted,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
