import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/data/rich/style_run.dart';
import 'package:remind_me/data/rich/styled_text.dart';
import 'package:remind_me/data/rich/task_body.dart';

void main() {
  const bold = Styles(bold: true);
  const italic = Styles(italic: true);
  StyleRun run(int start, int end, [Styles styles = bold]) =>
      StyleRun(start: start, end: end, styles: styles);

  group('styled text', () {
    test('keeps its runs sorted, merged and within the words', () {
      final text = StyledText('hello world', [
        run(6, 11),
        run(0, 3),
        run(3, 5),
        run(5, 5),
        run(11, 20, italic),
      ]);
      expect(text.runs, [run(0, 5), run(6, 11)]);
      expect(StyledText('plain', [run(0, 5, Styles.none)]).isPlain, isTrue);
    });

    test('says what typing at a point would get', () {
      final text = StyledText('hello world', [run(0, 5)]);
      expect(text.stylesAt(0), Styles.none, reason: 'before the run');
      expect(text.stylesAt(3), bold);
      expect(text.stylesAt(5), bold, reason: 'straight after keeps going');
      expect(text.stylesAt(6), Styles.none);
      expect(text.stylesIn(0, 5), bold);
      expect(text.stylesIn(3, 8), Styles.none, reason: 'not all bold');
    });

    test('restyles a range and leaves the rest', () {
      final text = StyledText('hello world')
          .restyle(2, 7, (s) => s.copyWith(bold: true));
      expect(text.runs, [run(2, 7)]);
      final both = text.restyle(4, 9, (s) => s.copyWith(italic: true));
      expect(both.runs, [
        run(2, 4),
        run(4, 7, const Styles(bold: true, italic: true)),
        run(7, 9, italic),
      ]);
      final off = both.restyle(0, 11, (s) => s.copyWith(bold: false));
      expect(off.runs, [run(4, 9, italic)]);
    });

    group('an edit', () {
      final text = StyledText('hello world', [run(0, 5)]);

      test('inside a run stretches it', () {
        final typed = text.replaced(2, 2, 'XX');
        expect(typed.text, 'heXXllo world');
        expect(typed.runs, [run(0, 7)]);
      });

      test('at the end of a run carries its style on', () {
        final typed = text.replaced(5, 5, '!');
        expect(typed.text, 'hello! world');
        expect(typed.runs, [run(0, 6)]);
      });

      test('at the end of a run stops when the bar says plain', () {
        final typed = text.replaced(5, 5, '!', typed: Styles.none);
        expect(typed.runs, [run(0, 5)]);
      });

      test('after a run shifts it not at all, and later runs along', () {
        final two = StyledText('hello world', [run(0, 5), run(6, 11, italic)]);
        final typed = two.replaced(6, 6, 'big ');
        expect(typed.text, 'hello big world');
        expect(typed.runs, [run(0, 5), run(10, 15, italic)]);
      });

      test('across a run\'s edge cuts the overlapped part', () {
        final cut = text.replaced(3, 8, '');
        expect(cut.text, 'helrld');
        expect(cut.runs, [run(0, 3)]);
        final over = StyledText('hello world', [run(6, 11)]).replaced(3, 8, '');
        expect(over.runs, [run(3, 6)]);
      });

      test('with the bar set styles the typed words', () {
        final typed = StyledText('hello').replaced(5, 5, ' there', typed: bold);
        expect(typed.runs, [run(5, 11)]);
        final swapped = StyledText('hello', [
          run(0, 5),
        ]).replaced(5, 5, '!', typed: italic);
        expect(swapped.runs, [run(0, 5), run(5, 6, italic)]);
      });

      test('over a whole run replaces it with the typed style', () {
        final replaced = text.replaced(0, 11, 'new', typed: italic);
        expect(replaced.text, 'new');
        expect(replaced.runs, [run(0, 3, italic)]);
      });
    });

    test('slices and joins with runs re-based', () {
      final text = StyledText('hello world', [run(0, 5), run(6, 11, italic)]);
      expect(
        text.slice(3),
        StyledText('lo world', [run(0, 2), run(3, 8, italic)]),
      );
      expect(text.slice(0, 3), StyledText('hel', [run(0, 3)]));
      expect(text.slice(0, 3) + text.slice(3), text);
    });

    test('round trips through json', () {
      final text = StyledText('hello world', [
        run(0, 5, const Styles(bold: true, highlight: Highlight.green)),
        run(6, 11, const Styles(link: 'https://example.com', underline: true)),
      ]);
      expect(StyledText.fromJson(text.toJson()), text);
      expect(StyledText.fromJson(const {'t': 'x'}), StyledText('x'));
    });
  });

  group('a task body', () {
    test('plain words become one paragraph per line', () {
      final body = TaskBody.plain('Buy milk\nand bread');
      expect(body.blocks, hasLength(2));
      expect(body.blocks.first.text, 'Buy milk');
      expect(body.plainText, 'Buy milk\nand bread');
      expect(body.hasWords, isTrue);
      expect(TaskBody.plain('  ').hasWords, isFalse);
    });

    test('never has no blocks at all', () {
      expect(TaskBody(const []).blocks, hasLength(1));
      expect(TaskBody.plain('').blocks.single.text, '');
    });

    test('counts its checklist', () {
      final body = TaskBody([
        Block.paragraph('Shopping'),
        Block(
          kind: BlockKind.check,
          content: StyledText('Milk'),
          checked: true,
        ),
        Block(kind: BlockKind.check, content: StyledText('Bread')),
      ]);
      expect(body.checklistProgress, (1, 2));
      expect(body.toggled(2).checklistProgress, (2, 2));
      expect(body.toggled(1).checklistProgress, (0, 2));
      expect(TaskBody.plain('x').checklistProgress, (0, 0));
    });

    test('a paragraph is never ticked', () {
      final item = Block(
        kind: BlockKind.check,
        content: StyledText('Milk'),
        checked: true,
      );
      expect(item.copyWith(kind: BlockKind.paragraph).checked, isFalse);
    });

    test('trims trailing empty paragraphs and keeps one', () {
      final body = TaskBody([
        Block.paragraph('Buy milk'),
        Block.paragraph(''),
        Block.paragraph(' '),
      ]);
      expect(body.trimmed().blocks, hasLength(1));
      expect(TaskBody.plain('').trimmed().blocks, hasLength(1));
    });

    test('round trips through json, styles and ticks included', () {
      final body = TaskBody([
        Block(
          kind: BlockKind.paragraph,
          content: StyledText('Call Sam', [run(0, 4)]),
        ),
        Block(
          kind: BlockKind.check,
          content: StyledText('Milk'),
          checked: true,
        ),
      ]);
      final back = TaskBody.decode(body.encode());
      expect(back.blocks.first.content, body.blocks.first.content);
      expect(back.blocks[1].kind, BlockKind.check);
      expect(back.blocks[1].checked, isTrue);
      expect(back.plainText, 'Call Sam\nMilk');
    });
  });
}
