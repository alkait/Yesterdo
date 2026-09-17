import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_labels.dart';
import '../../core/day.dart';
import '../../state/day_notice.dart';
import '../../state/providers.dart';
import '../branded/branded.dart';

/// The word at the foot of the list when a task was saved onto another day:
/// which task, which day, and a way to go there. Going there points the
/// task's card out, the way a search result does.
///
/// It floats over the day rather than pushing it up. It goes of its own
/// accord after a while, when pushed away, or the moment the day it names is
/// the day being looked at, since by then it has nothing left to say.
class DayNoticeBanner extends ConsumerStatefulWidget {
  const DayNoticeBanner({super.key});

  @override
  ConsumerState<DayNoticeBanner> createState() => _DayNoticeBannerState();
}

class _DayNoticeBannerState extends ConsumerState<DayNoticeBanner> {
  Timer? _dwell;

  @override
  void initState() {
    super.initState();
    ref.listenManual(dayNoticeProvider, (_, notice) {
      _dwell?.cancel();
      if (notice == null) return;
      _dwell = Timer(Brand.noticeDwell, _clear);
    });
  }

  @override
  void dispose() {
    _dwell?.cancel();
    super.dispose();
  }

  void _clear() {
    if (mounted) ref.read(dayNoticeProvider.notifier).clear();
  }

  void _goThere(DayNotice notice) {
    ref.read(spotlightProvider.notifier).raise(notice.day, notice.key);
    ref.read(selectedDayProvider.notifier).select(dateFromEpochDay(notice.day));
    _clear();
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(dayNoticeProvider);
    if (notice == null) return const SizedBox.shrink();

    final date = dateFromEpochDay(notice.day);
    return BrandedBanner(
      key: const ValueKey('day-notice'),
      message: notice.line,
      detail:
          '${dayHeadline(date, now: ref.watch(clockProvider)())}, '
          '${longDate(date)}',
      actionLabel: 'Go',
      onAction: () => _goThere(notice),
      onDismiss: _clear,
    );
  }
}
