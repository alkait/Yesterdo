import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/data/rich/style_run.dart';
import 'package:remind_me/data/rich/styled_text.dart';
import 'package:remind_me/data/rich/task_body.dart';
import 'package:remind_me/ui/branded/branded.dart';

import 'app_flow_test.dart' show addTask, bootApp, tileFor, actOn;
import 'support/memory_device_bridge.dart';

const guard = BrandedRichController.guard;

/// The fields of the editor, top to bottom.
List<TextField> fields(WidgetTester tester) =>
    tester.widgetList<TextField>(find.byType(TextField)).toList();

/// Selects [start] to [end] of the words in the [index]th block.
void select(WidgetTester tester, int index, int start, int end) {
  fields(tester)[index].controller!.selection = TextSelection(
    baseOffset: start + 1,
    extentOffset: end + 1,
  );
}

/// Types into the [index]th block the way the system does: the whole
/// value, guard included, with the caret after the new words.
Future<void> typeInto(WidgetTester tester, int index, String words) async {
  final field = find.byType(TextField).at(index);
  await tester.enterText(field, '$guard$words');
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey('format-$key')));
  await tester.pump();
}

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Add a task'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bar is dark until a block has the caret', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    // The editor took the caret on arrival.
    final bold = tester.widget<BrandedIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('format-bold')),
        matching: find.byType(BrandedIcon),
      ),
    );
    expect(bold.tone, BrandedTone.primary);
  });

  testWidgets('selected words go bold and come back bold on the card', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Buy milk today');
    select(tester, 0, 0, 3);
    await tapKey(tester, 'bold');
    final lit = tester.widget<BrandedIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('format-bold')),
        matching: find.byType(BrandedIcon),
      ),
    );
    expect(lit.tone, BrandedTone.accent);
    await save(tester);

    final body = tileFor(tester, 'Buy milk today').todo.body;
    expect(body.first.content.runs, [
      const StyleRun(start: 0, end: 3, styles: Styles(bold: true)),
    ]);
    // Drawn bold on the card.
    final rich = tester.widget<Text>(
      find.descendant(
        of: find.byType(BrandedRichText),
        matching: find.byType(Text),
      ),
    );
    final span = rich.textSpan! as TextSpan;
    final first = span.children!.first as TextSpan;
    expect(
      ((first.children ?? [first]).first as TextSpan).style?.fontWeight ??
          first.style?.fontWeight,
      isNotNull,
    );
  });

  testWidgets('the bar set with nothing selected styles what is typed next', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Plain ');
    await tapKey(tester, 'highlight');
    await typeInto(tester, 0, 'Plain bright');
    await tapKey(tester, 'highlight');
    await tapKey(tester, 'highlight');
    await typeInto(tester, 0, 'Plain bright blue');
    await save(tester);

    final runs = tileFor(
      tester,
      'Plain bright blue',
    ).todo.body.first.content.runs;
    expect(runs, [
      const StyleRun(
        start: 6,
        end: 12,
        styles: Styles(highlight: Highlight.yellow),
      ),
      const StyleRun(
        start: 12,
        end: 17,
        styles: Styles(highlight: Highlight.blue),
      ),
    ]);
  });

  testWidgets(
    'a checklist is made, grows on return, and ends on an empty item',
    (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      await openEditor(tester);
      await typeInto(tester, 0, 'Shopping');
      // Return: a new paragraph below, made a checklist item.
      await typeInto(tester, 0, 'Shopping\n');
      await tester.pumpAndSettle();
      expect(fields(tester), hasLength(2));
      await tapKey(tester, 'checklist');
      await tester.pump();
      expect(find.byType(BrandedCheckBox), findsOneWidget);

      await typeInto(tester, 1, 'Milk');
      await typeInto(tester, 1, 'Milk\n');
      await tester.pumpAndSettle();
      expect(find.byType(BrandedCheckBox), findsNWidgets(2), reason: 'grows');
      await typeInto(tester, 2, 'Bread');
      await typeInto(tester, 2, 'Bread\n');
      await tester.pumpAndSettle();
      expect(find.byType(BrandedCheckBox), findsNWidgets(3));
      // Return on the empty item ends the list.
      await typeInto(tester, 3, '\n');
      await tester.pumpAndSettle();
      expect(find.byType(BrandedCheckBox), findsNWidgets(2));
      expect(fields(tester), hasLength(4));

      await save(tester);
      final body = tileFor(tester, 'Shopping').todo.body;
      expect(body.blocks.map((b) => b.kind), [
        BlockKind.paragraph,
        BlockKind.check,
        BlockKind.check,
      ], reason: 'the empty paragraph at the end is trimmed');
      expect(body.checklistProgress, (0, 2));
      expect(find.text('0 of 2'), findsOneWidget);
    },
  );

  testWidgets('backspace at the start of a block joins it to the one above', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Buy milk\nand bread');
    await tester.pumpAndSettle();
    expect(fields(tester), hasLength(2));

    // Backspace at the start: the guard alone goes.
    await tester.enterText(find.byType(TextField).at(1), 'and bread');
    await tester.pumpAndSettle();
    expect(fields(tester), hasLength(1));
    expect(fields(tester).single.controller!.text, '${guard}Buy milkand bread');
    expect(fields(tester).single.controller!.selection.extentOffset, 9);
  });

  testWidgets('a tap on the box in the editor ticks nothing', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await tapKey(tester, 'checklist');
    await typeInto(tester, 0, 'Milk');
    await tester.tap(find.byType(BrandedCheckBox));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BrandedCheckBox>(find.byType(BrandedCheckBox)).checked,
      isFalse,
    );
    await save(tester);
    expect(tileFor(tester, 'Milk').todo.body.checklistProgress, (0, 1));
  });

  testWidgets('ticks are made in the read view and shown on the card', (
    tester,
  ) async {
    final device = MemoryDeviceBridge();
    await tester.pumpWidget(bootApp(device: device));
    await tester.pumpAndSettle();
    await openEditor(tester);
    await tapKey(tester, 'checklist');
    await typeInto(tester, 0, 'Milk');
    await typeInto(tester, 0, 'Milk\n');
    await tester.pumpAndSettle();
    await typeInto(tester, 1, 'Bread');
    await save(tester);
    expect(find.text('0 of 2'), findsOneWidget);

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('Task'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tick-Milk')));
    // Ticked, it flies to the foot rather than jumping: a spacer holds its
    // old place while the copy travels.
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('flight-spacer-Milk#0')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flight-spacer-Milk#0')), findsNothing);
    // Heard, as done on the day is.
    expect(device.doneSounds, 1);
    // Landed under the open item.
    expect(
      tester.getTopLeft(find.text('Bread')).dy,
      lessThan(tester.getTopLeft(find.text('Milk')).dy),
    );
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    final tile = tileFor(tester, 'Bread');
    expect(tile.todo.body.blocks.last.checked, isTrue);
    // The card carries one circle, for done; the item's own box is not
    // drawn there, the strike says it is ticked.
    expect(find.byType(BrandedCheckBox), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('a right-to-left item carries its box on the right, and the '
      'whole line ticks in the read view', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await tapKey(tester, 'checklist');
    await typeInto(tester, 0, 'حليب');
    await tester.pumpAndSettle();
    // In the editor the box stands to the right of the field.
    expect(
      tester.getCenter(find.byType(BrandedCheckBox)).dx,
      greaterThan(tester.getCenter(find.byType(TextField).first).dx),
      reason: 'editor box on the right',
    );
    await save(tester);

    // The card shows no box of the item's own; its one circle is for done
    // and sits at the leading edge whatever the words' direction.
    expect(
      tester.getCenter(find.byType(BrandedCheckBox)).dx,
      lessThan(tester.getCenter(find.text('حليب')).dx),
      reason: 'done circle on the left',
    );

    // In the read view, a tap on the words ticks the item.
    await tester.tap(find.text('حليب'));
    await tester.pumpAndSettle();
    expect(find.text('Task'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('tick-حليب'))).dx,
      greaterThan(tester.getCenter(find.text('حليب')).dx),
      reason: 'read view box on the right',
    );
    await tester.tap(find.text('حليب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(tileFor(tester, 'حليب').todo.body.first.checked, isTrue);
  });

  testWidgets('a link is set on the selection and opens from the read view', (
    tester,
  ) async {
    final device = MemoryDeviceBridge();
    await tester.pumpWidget(bootApp(device: device));
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'See the docs');
    select(tester, 0, 8, 12);
    await tapKey(tester, 'link');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('link-address')),
      'example.com',
    );
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await save(tester);

    final runs = tileFor(tester, 'See the docs').todo.body.first.content.runs;
    expect(runs, [
      const StyleRun(
        start: 8,
        end: 12,
        styles: Styles(link: 'https://example.com'),
      ),
    ]);

    await tester.tap(find.text('See the docs'));
    await tester.pumpAndSettle();
    // Tap right on the linked words, wherever the font put them.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(BrandedRichText),
        matching: find.byType(RichText),
      ),
    );
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 8, extentOffset: 12),
        )
        .first;
    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    await tester.pumpAndSettle();
    expect(device.opened, ['https://example.com']);
  });

  testWidgets('editing keeps the styles and the checklist', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Call Sam');
    select(tester, 0, 5, 8);
    await tapKey(tester, 'italic');
    await save(tester);

    await actOn(tester, 'Call Sam', 'Edit');
    final field = fields(tester).single;
    expect(field.controller!.text, '${guard}Call Sam');
    await typeInto(tester, 0, 'Call Sam now');
    await save(tester);
    // Typed straight after the italic words, the new ones are italic too.
    final runs = tileFor(tester, 'Call Sam now').todo.body.first.content.runs;
    expect(runs, [
      const StyleRun(start: 5, end: 12, styles: Styles(italic: true)),
    ]);
  });

  testWidgets('the store keeps a body through a repeat rule', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Take the pills');
    select(tester, 0, 0, 4);
    await tapKey(tester, 'underline');
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every day').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(tileFor(tester, 'Take the pills').todo.body.first.content.runs, [
      const StyleRun(start: 0, end: 4, styles: Styles(underline: true)),
    ]);
    expect(addTask, isNotNull);
  });

  test('a block moves to where it is dropped and keeps its tick', () {
    final body = TaskBody([
      Block.paragraph('Shopping'),
      Block(kind: BlockKind.check, content: StyledText('Milk')),
      Block(kind: BlockKind.check, content: StyledText('Eggs'), checked: true),
      Block(kind: BlockKind.check, content: StyledText('Jam')),
    ]);
    // Dropped after Jam: its place once the others have closed up.
    final down = body.reordered(1, 3);
    expect(down.blocks.map((b) => b.text), ['Shopping', 'Eggs', 'Jam', 'Milk']);
    final up = body.reordered(3, 1);
    expect(up.blocks.map((b) => b.text), ['Shopping', 'Jam', 'Milk', 'Eggs']);
    expect(up.blocks[3].checked, isTrue);
    expect(up.checklistProgress, (1, 3));
  });

  test(
    'a ticked item sinks to the foot of its list, an unticked one rises',
    () {
      final body = TaskBody([
        Block.paragraph('Shopping'),
        Block(kind: BlockKind.check, content: StyledText('Milk')),
        Block(kind: BlockKind.check, content: StyledText('Eggs')),
        Block(kind: BlockKind.check, content: StyledText('Jam'), checked: true),
        Block.paragraph('After'),
      ]);
      final sunk = body.ticked(1);
      expect(sunk.blocks.map((b) => b.text), [
        'Shopping',
        'Eggs',
        'Jam',
        'Milk',
        'After',
      ]);
      expect(sunk.blocks[3].checked, isTrue, reason: 'under the earlier tick');

      expect(sunk.blocks[3].home, 0, reason: 'where it stood in its list');

      // Unticked again, it goes back to where it was, and forgets.
      final risen = sunk.ticked(3);
      expect(risen.blocks.map((b) => b.text), [
        'Shopping',
        'Milk',
        'Eggs',
        'Jam',
        'After',
      ]);
      expect(risen.blocks[1].checked, isFalse);
      expect(risen.blocks[1].home, isNull);

      // Its place can be past the open items by then: it lands at their
      // foot.
      final eggsToo = sunk.ticked(1);
      expect(eggsToo.blocks.map((b) => b.text), [
        'Shopping',
        'Jam',
        'Milk',
        'Eggs',
        'After',
      ]);
      final eggsBack = eggsToo.ticked(3);
      expect(eggsBack.blocks.map((b) => b.text), [
        'Shopping',
        'Eggs',
        'Jam',
        'Milk',
        'After',
      ]);

      // The place survives being stored.
      final kept = TaskBody.decode(sunk.encode());
      expect(kept.blocks[3].home, 0);
      expect(kept.ticked(3).blocks.map((b) => b.text), [
        'Shopping',
        'Milk',
        'Eggs',
        'Jam',
        'After',
      ]);
    },
  );

  testWidgets('items are put in a new order on the read view by holding one', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Shopping\n- Milk\n- Bread\n- Jam');
    await tester.pumpAndSettle();
    await save(tester);

    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Jam')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.text('Milk')));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Jam')).dy,
      lessThan(tester.getTopLeft(find.text('Milk')).dy),
    );

    // And down again: dropped just past Milk, it lands between Milk and
    // Bread, not above Milk.
    final jam = tester.getCenter(find.text('Jam'));
    final row = tester.getCenter(find.text('Milk')).dy - jam.dy;
    final down = await tester.startGesture(jam);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // Far enough that the lifted copy's foot is past Milk's middle, not so
    // far that it reaches Bread's.
    await down.moveTo(jam + Offset(0, row * 0.75));
    await tester.pumpAndSettle();
    await down.up();
    await tester.pumpAndSettle();
    final tops = [
      for (final word in ['Milk', 'Jam', 'Bread'])
        tester.getTopLeft(find.text(word)).dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    final body = tileFor(tester, 'Shopping').todo.body;
    expect(body.blocks.map((b) => b.text), [
      'Shopping',
      'Milk',
      'Jam',
      'Bread',
    ]);
    expect(body.blocks.first.kind, BlockKind.paragraph, reason: 'stays put');
  });

  testWidgets('a ticked item holds the foot and nothing is dropped below it', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Shopping\n- Milk\n- Bread\n- Jam');
    await tester.pumpAndSettle();
    await save(tester);
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();

    // Milk dragged to the very bottom lands above Jam, which holds the foot.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Milk')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(
      tester.getBottomLeft(find.text('Jam')) + const Offset(40, 8),
    );
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    final body = tileFor(tester, 'Shopping').todo.body;
    expect(body.blocks.map((b) => b.text), [
      'Shopping',
      'Bread',
      'Milk',
      'Jam',
    ]);
    expect(body.blocks.last.checked, isTrue);
  });

  testWidgets('pasted lines become blocks of their own', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Plan\r\nMilk\n\nBread');
    await tester.pumpAndSettle();
    // Three lines, the blank one left out, and the caret at the end of the
    // last.
    expect(fields(tester), hasLength(3));
    expect(fields(tester)[2].controller!.selection.baseOffset, 6);

    await save(tester);
    final body = tileFor(tester, 'Plan').todo.body;
    expect(body.blocks.map((b) => b.text), ['Plan', 'Milk', 'Bread']);
    expect(body.blocks.every((b) => b.kind == BlockKind.paragraph), isTrue);
  });

  testWidgets('a pasted list becomes a checklist, every item open', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Shopping\n• Milk\n  - Bread\n[x] Eggs\n[ ] Jam');
    await tester.pumpAndSettle();
    expect(fields(tester), hasLength(5));
    expect(find.byType(BrandedCheckBox), findsNWidgets(4));

    await save(tester);
    final body = tileFor(tester, 'Shopping').todo.body;
    expect(body.blocks.map((b) => b.text), [
      'Shopping',
      'Milk',
      'Bread',
      'Eggs',
      'Jam',
    ]);
    expect(body.blocks.first.kind, BlockKind.paragraph);
    expect(body.checklistProgress, (0, 4), reason: 'a pasted tick is dropped');
  });

  testWidgets('the editor draws a ticked item open and keeps its tick', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Shopping\n- Milk\n- Bread');
    await tester.pumpAndSettle();
    await save(tester);
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<BrandedCheckBox>(find.byType(BrandedCheckBox))
          .map((box) => box.checked),
      [false, false],
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(tileFor(tester, 'Shopping').todo.body.checklistProgress, (
      1,
      2,
    ), reason: 'the tick made on the read view outlives the edit');
  });

  test('a body unticked is as it was written', () {
    Block item(String text) =>
        Block(kind: BlockKind.check, content: StyledText(text));
    final written = TaskBody([item('Milk'), item('Bread'), item('Jam')]);
    final ticked = written.ticked(0).ticked(0);
    expect(ticked.blocks.map((b) => b.text), ['Jam', 'Milk', 'Bread']);
    final open = ticked.unticked();
    expect(open.blocks.map((b) => b.text), ['Milk', 'Bread', 'Jam']);
    expect(open.checklistProgress, (0, 3));
    expect(open.blocks.every((b) => b.home == null), isTrue);

    // New words take the old ticks where the item is still there.
    final rewritten = TaskBody([item('Eggs'), item('Bread'), item('Jam')]);
    final kept = rewritten.withTicksOf(ticked);
    expect(kept.blocks.map((b) => b.text), ['Eggs', 'Jam', 'Bread']);
    expect(kept.blocks.map((b) => b.checked), [false, false, true]);
  });

  testWidgets('a list pasted into an empty block starts with an item', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, '- Milk\n- Bread');
    await tester.pumpAndSettle();
    expect(find.byType(BrandedCheckBox), findsNWidgets(2));
    await save(tester);
    final body = tileFor(tester, 'Milk').todo.body;
    expect(body.blocks.map((b) => b.text), ['Milk', 'Bread']);
    expect(body.checklistProgress, (0, 2));
  });

  testWidgets('a typed dash is left alone', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, '- Milk');
    await typeInto(tester, 0, '- Milk\n');
    await tester.pumpAndSettle();
    expect(find.byType(BrandedCheckBox), findsNothing);
    expect(fields(tester)[0].controller!.text, '$guard- Milk');
  });
}
