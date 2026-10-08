import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/rich/styled_text.dart';
import 'package:remind_me/data/rich/task_body.dart';
import 'package:remind_me/ui/task_view_page.dart';

import 'app_flow_test.dart' show bootApp;
import 'support/memory_todo_store.dart';

/// A long checklist on the read view: dragging an item towards the top of
/// the screen scrolls the page, the way a drag on the day scrolls the day.
void main() {
  const itemCount = 40;

  Future<MemoryTodoStore> storeWithLongList() async {
    final store = MemoryTodoStore();
    await store.insert(
      day: todayDate().epochDay,
      body: TaskBody([
        Block.paragraph('Shopping'),
        for (var i = 1; i <= itemCount; i++)
          Block(kind: BlockKind.check, content: StyledText('Item $i')),
      ]),
    );
    return store;
  }

  Future<void> openTask(WidgetTester tester) async {
    await tester.tap(find.textContaining('Shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Task'), findsOneWidget);
  }

  ScrollPosition pageScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(TaskViewPage),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  testWidgets('the checklist scrolls with the page, not on its own', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp(store: await storeWithLongList()));
    await tester.pumpAndSettle();
    await openTask(tester);

    // One scrollable for the whole page: the checklist is a sliver of it.
    expect(
      find.descendant(
        of: find.byType(TaskViewPage),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item $itemCount'), findsNothing, reason: 'off screen');
  });

  testWidgets('dragging an item to the top edge scrolls the page up', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp(store: await storeWithLongList()));
    await tester.pumpAndSettle();
    await openTask(tester);

    // Down to the foot of the list first.
    final page = pageScroll(tester);
    page.jumpTo(page.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Item $itemCount'), findsOneWidget);
    final before = page.pixels;

    // Lift the last item and hold it against the top of the screen.
    final start = tester.getCenter(find.text('Item $itemCount'));
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(start.dx, 80));
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(page.pixels, lessThan(before), reason: 'the page scrolled up');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
