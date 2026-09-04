import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/data/rich/style_run.dart';
import 'package:remind_me/data/rich/styled_text.dart';
import 'package:remind_me/ui/branded/branded_rich_controller.dart';

void main() {
  const bold = Styles(bold: true);
  const guard = BrandedRichController.guard;
  StyleRun run(int start, int end, [Styles styles = bold]) =>
      StyleRun(start: start, end: end, styles: styles);

  /// What the system does when a key is typed: the value with the words
  /// changed and the caret after them.
  void type(TextEditingController c, String text, int caret) {
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  group('the rich controller', () {
    test('follows typing with its runs', () {
      final c = BrandedRichController(
        content: StyledText('hello world', [run(0, 5)]),
      );
      type(c, 'hello big world', 10);
      expect(c.content.text, 'hello big world');
      expect(c.content.runs, [run(0, 5)]);
      type(c, 'hello! big world', 6);
      expect(c.content.runs, [run(0, 6)], reason: 'typed at the run\'s end');
    });

    test('styles a selection, or the words typed next', () {
      final c = BrandedRichController(content: StyledText('hello world'));
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      c.toggleBold();
      expect(c.content.runs, [run(0, 5)]);
      expect(c.current, bold);

      c.selection = const TextSelection.collapsed(offset: 11);
      expect(c.current, Styles.none);
      c.toggleItalic();
      expect(c.current, const Styles(italic: true));
      type(c, 'hello world!', 12);
      expect(c.content.runs, [
        run(0, 5),
        run(11, 12, const Styles(italic: true)),
      ]);
      expect(c.current, const Styles(italic: true), reason: 'carries on');
    });

    test('a moved caret forgets what the bar set', () {
      final c = BrandedRichController(content: StyledText('hello'));
      c.selection = const TextSelection.collapsed(offset: 5);
      c.toggleBold();
      c.selection = const TextSelection.collapsed(offset: 2);
      expect(c.current, Styles.none);
    });

    test('cycles the highlight round', () {
      final c = BrandedRichController(content: StyledText('hi'));
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      for (final expected in [
        Highlight.yellow,
        Highlight.green,
        Highlight.blue,
        null,
      ]) {
        c.cycleHighlight();
        expect(c.current.highlight, expected);
      }
    });

    test('links the selection, or types the address in as one', () {
      final c = BrandedRichController(content: StyledText('see here'));
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 8);
      c.setLink('https://a.example');
      expect(c.content.runs, [
        run(4, 8, const Styles(link: 'https://a.example')),
      ]);
      c.setLink(null);
      expect(c.content.isPlain, isTrue);

      c.selection = const TextSelection.collapsed(offset: 8);
      c.setLink('https://b.example');
      expect(c.text, 'see herehttps://b.example');
      expect(c.content.runs, [
        run(8, 25, const Styles(link: 'https://b.example')),
      ]);
      expect(c.selection.extentOffset, 25);
    });

    group('guarded', () {
      test('keeps an invisible character in front of the words', () {
        final c = BrandedRichController(
          content: StyledText('hello'),
          guarded: true,
        );
        expect(c.text, '${guard}hello');
        expect(c.content.text, 'hello');
        c.selection = const TextSelection.collapsed(offset: 0);
        expect(c.selection.extentOffset, 1, reason: 'never before it');
      });

      test('hears backspace at the very start', () {
        var heard = 0;
        final c = BrandedRichController(
          content: StyledText('hello'),
          guarded: true,
          onBackspaceAtStart: () => heard++,
        );
        type(c, 'hello', 0);
        expect(heard, 1);
        expect(c.text, '${guard}hello', reason: 'the guard is put back');
        expect(c.content.text, 'hello');
      });

      test('takes a whole new value as words, guard put back', () {
        final c = BrandedRichController(
          content: StyledText('hello'),
          guarded: true,
        );
        type(c, 'goodbye', 7);
        expect(c.text, '${guard}goodbye');
        expect(c.content.text, 'goodbye');
        expect(c.selection.extentOffset, 8);
      });

      test('styles the right words despite the guard', () {
        final c = BrandedRichController(
          content: StyledText('hello world'),
          guarded: true,
        );
        c.selection = const TextSelection(baseOffset: 1, extentOffset: 6);
        c.toggleBold();
        expect(c.content.runs, [run(0, 5)]);
        type(c, '${guard}hello! world', 7);
        expect(c.content.text, 'hello! world');
        expect(c.content.runs, [run(0, 6)]);
      });
    });

    test('hands the words after a line break to a new block', () {
      StyledText? handed;
      final c = BrandedRichController(
        content: StyledText('hello world', [run(6, 11)]),
        guarded: true,
        onSplit: (after) => handed = after,
      );
      type(c, '${guard}hello\nworld', 7);
      expect(c.content, StyledText('hello'));
      expect(c.selection.extentOffset, 6);
      expect(handed, StyledText('world', [run(0, 5)]));
    });

    test('without a split handler a line break is just a character', () {
      final c = BrandedRichController(content: StyledText('a'));
      type(c, 'a\nb', 3);
      expect(c.content.text, 'a\nb');
    });
  });
}
