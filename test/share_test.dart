import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/data/rich/styled_text.dart';
import 'package:remind_me/data/rich/task_body.dart';

import 'app_flow_test.dart' show addTask, bootApp;
import 'support/memory_device_bridge.dart';

void main() {
  test('the words shared are the words alone, boxes before the items', () {
    final body = TaskBody([
      Block.paragraph('Shopping'),
      Block(kind: BlockKind.check, content: StyledText('Milk')),
      Block(kind: BlockKind.check, content: StyledText('Eggs'), checked: true),
      Block.image('photo.jpg'),
      Block.paragraph('After the shop'),
    ]);
    expect(body.shareText, 'Shopping\n☐ Milk\n☑ Eggs\nAfter the shop');
  });

  testWidgets('Share on the read view hands the words to the device', (
    tester,
  ) async {
    final device = MemoryDeviceBridge();
    await tester.pumpWidget(bootApp(device: device));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await tester.tap(find.text('Buy milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();
    expect(device.shared, ['Buy milk']);
    // Still on the read view, Edit beside it.
    expect(find.text('Edit'), findsOneWidget);
  });
}
