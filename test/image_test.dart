import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/rich/task_body.dart';
import 'package:remind_me/data/todo.dart';
import 'package:remind_me/platform/device_bridge.dart';
import 'package:remind_me/platform/image_sweep.dart';
import 'package:remind_me/ui/branded/branded.dart';

import 'app_flow_test.dart' show bootApp, tileFor, visibleTitles;
import 'rich_editor_test.dart' show fields, openEditor, save, tapKey, typeInto;
import 'support/memory_device_bridge.dart';
import 'support/memory_todo_store.dart';

/// The smallest PNG there is: one white pixel.
final onePixel = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, //
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00, //
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// A folder of pictures for one test, cleared away after. Made with
/// blocking calls: a real async file call never completes under the widget
/// tester's clock.
Future<MemoryDeviceBridge> pictureFolder(List<String> names) async {
  final folder = Directory.systemTemp.createTempSync('remind_me_images');
  addTearDown(() => folder.deleteSync(recursive: true));
  for (final name in names) {
    File('${folder.path}/$name').writeAsBytesSync(onePixel);
  }
  return MemoryDeviceBridge()..directory = folder.path;
}

/// A picture already decoded, handed over at once. Decoding a file never
/// completes under the tester's clock, so the brand image is given these.
class ReadyImage extends ImageProvider<ReadyImage> {
  const ReadyImage(this.image, this.path);

  final ui.Image image;
  final String path;

  @override
  Future<ReadyImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(ReadyImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image.clone())),
      );

  @override
  bool operator ==(Object other) => other is ReadyImage && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Points the brand image at ready-made pictures for the test, and back
/// at files after. Drawn rather than decoded: decoding never completes
/// under the clock.
Future<void> useReadyImages(WidgetTester tester) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const Color(0xFF888888),
  );
  final image = recorder.endRecording().toImageSync(4, 4);
  final before = BrandedImage.load;
  BrandedImage.load = (path) => ReadyImage(image, path);
  addTearDown(() => BrandedImage.load = before);
}

void main() {
  group('an image block', () {
    test('round trips through json and counts as words', () {
      final body = TaskBody([Block.paragraph('See'), Block.image('a.jpg')]);
      final back = TaskBody.decode(body.encode());
      expect(back.blocks[1].isImage, isTrue);
      expect(back.blocks[1].image, 'a.jpg');
      expect(back.images, ['a.jpg']);
      expect(back.plainText, 'See', reason: 'pictures are not words');
      expect(TaskBody([Block.image('a.jpg')]).hasWords, isTrue);
      expect(TaskBody([Block.image('a.jpg')]).firstText, isNull);
      expect(TaskBody([Block.image('a.jpg')]).trimmed().blocks, hasLength(1));
    });

    test('a task of pictures alone still has a line to say', () {
      final todo = Todo(
        body: TaskBody([Block.image('a.jpg')]),
        done: false,
        position: 0,
      );
      expect(todo.firstLine, 'Picture');
      expect(todo.title, '');
    });
  });

  testWidgets('a picture is chosen from the bar and shown in full', (
    tester,
  ) async {
    await useReadyImages(tester);
    final device = await pictureFolder(['one.png']);
    device.toPick.add('one.png');
    await tester.pumpWidget(bootApp(device: device));
    await tester.pumpAndSettle();
    await openEditor(tester);
    await typeInto(tester, 0, 'Receipt');
    await tapKey(tester, 'image');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('image-library')));
    await tester.pumpAndSettle();

    expect(device.picked, [ImageSource.library]);
    expect(find.byType(BrandedImage), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2), reason: 'room after it');
    expect(
      fields(tester).first.focusNode!.hasFocus,
      isFalse,
      reason: 'the caret moved on to the room after the picture',
    );
    await save(tester);

    final body = tileFor(tester, 'Receipt').todo.body;
    expect(body.blocks.map((b) => b.kind), [
      BlockKind.paragraph,
      BlockKind.image,
    ]);
    expect(find.byType(BrandedImage), findsNothing, reason: 'no thumbnail');
    expect(visibleTitles(tester), ['Receipt']);

    // In full on the read view, opening large on a tap.
    await tester.tap(find.text('Receipt'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('picture-one.png')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('picture-one.png')));
    await tester.pumpAndSettle();
    expect(find.text('Picture'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('paste and camera go through the bridge too', (tester) async {
    await useReadyImages(tester);
    final device = await pictureFolder(['p.png', 'c.png']);
    device.toPick.addAll(['p.png', 'c.png']);
    await tester.pumpWidget(bootApp(device: device));
    await tester.pumpAndSettle();
    await openEditor(tester);
    await tapKey(tester, 'image');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('image-paste')));
    await tester.pumpAndSettle();
    expect(device.pastes, 1);
    await tapKey(tester, 'image');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('image-camera')));
    await tester.pumpAndSettle();
    expect(device.picked, [ImageSource.camera]);
    expect(find.byType(BrandedImage), findsNWidgets(2));

    // A pick backed out of adds nothing.
    await tapKey(tester, 'image');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('image-library')));
    await tester.pumpAndSettle();
    expect(find.byType(BrandedImage), findsNWidgets(2));

    // Pictures alone can be saved, and the card says so.
    await save(tester);
    expect(find.text('Picture'), findsOneWidget);
  });

  testWidgets('a picture can be taken out again in the editor', (tester) async {
    await useReadyImages(tester);
    final device = await pictureFolder(['one.png']);
    final store = MemoryTodoStore();
    await store.insert(
      day: todayDate().epochDay,
      body: TaskBody([Block.paragraph('Receipt'), Block.image('one.png')]),
    );
    await tester.pumpWidget(bootApp(store: store, device: device));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Receipt'), const Offset(200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(BrandedImage), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey('remove-image-${device.directory}/one.png')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BrandedImage), findsNothing);
    await save(tester);
    expect(tileFor(tester, 'Receipt').todo.body.images, isEmpty);
  });

  test('the sweep clears pictures nobody refers to', () async {
    final folder = await Directory.systemTemp.createTemp('remind_me_sweep');
    addTearDown(() => folder.delete(recursive: true));
    for (final name in ['kept.jpg', 'ruled.jpg', 'stray.jpg']) {
      File('${folder.path}/$name').writeAsBytesSync(onePixel);
    }
    final store = MemoryTodoStore();
    await store.insert(day: 1, body: TaskBody([Block.image('kept.jpg')]));
    await store.insertSeries(
      day: 1,
      body: TaskBody([Block.paragraph('x'), Block.image('ruled.jpg')]),
      rule: RepeatRule.daily(1),
    );

    final gone = await ImageSweep(store, folder.path).run();
    expect(gone, ['stray.jpg']);
    expect(File('${folder.path}/kept.jpg').existsSync(), isTrue);
    expect(File('${folder.path}/ruled.jpg').existsSync(), isTrue);
    expect(await ImageSweep(store, '${folder.path}/none').run(), isEmpty);
  });
}
