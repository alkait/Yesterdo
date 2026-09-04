import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'widgets/add_task_bar.dart';
import 'widgets/attention_listener.dart';
import 'widgets/date_header.dart';
import 'widgets/day_swiper.dart';
import 'widgets/todo_list_view.dart';
import 'widgets/wake_refresh.dart';

/// The whole app: a day, its tasks, and a way to add one. A change of day
/// slides the old page out and the new one in, from the side the change
/// came from.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int? _lastDay;
  int _direction = 1;

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDayProvider);
    final day = date.epochDay;
    // Forwards in time comes in from the right; a jump on the month grid
    // is judged the same way.
    if (_lastDay != null && day != _lastDay) {
      _direction = day > _lastDay! ? 1 : -1;
    }
    _lastDay = day;

    return WakeRefresh(
      child: AttentionListener(
        child: BrandedScaffold(
          children: [
            Expanded(
              child: DaySwiper(
                child: BrandedSlideSwitcher(
                  pageKey: day,
                  direction: _direction,
                  child: Column(
                    children: [
                      DateHeader(date: date),
                      Expanded(child: TodoListView(day: day)),
                    ],
                  ),
                ),
              ),
            ),
            const AddTaskBar(),
          ],
        ),
      ),
    );
  }
}
