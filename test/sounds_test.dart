import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/data/done_sound.dart';
import 'package:remind_me/state/app_sounds.dart';
import 'package:remind_me/state/done_sound_choice.dart';

import 'app_flow_test.dart' show actOn, addTask, bootApp;
import 'support/memory_device_bridge.dart';
import 'support/memory_settings_store.dart';

/// The app's own sounds: whether they play, and which one marks done.
void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('sounds can be turned off, and done then plays nothing', (
    tester,
  ) async {
    final device = MemoryDeviceBridge();
    final settings = MemorySettingsStore();
    await tester.pumpWidget(bootApp(device: device, settings: settings));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await openSettings(tester);
    expect(find.text('App sounds'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-sounds')));
    await tester.pumpAndSettle();
    expect(await settings.read(AppSounds.settingKey), 'off');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await actOn(tester, 'Buy milk', 'Done');
    expect(device.donePlayed, isEmpty);
  });

  testWidgets('the done sound is chosen on a sheet, heard as it is picked', (
    tester,
  ) async {
    final device = MemoryDeviceBridge();
    final settings = MemorySettingsStore();
    await tester.pumpWidget(bootApp(device: device, settings: settings));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await openSettings(tester);
    expect(find.text('Complete'), findsOneWidget, reason: 'the row reads it');
    await tester.tap(find.byKey(const ValueKey('settings-done-sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('done-sound-notify')));
    await tester.pumpAndSettle();
    expect(device.donePlayed, [DoneSound.notify], reason: 'heard on pick');
    expect(await settings.read(DoneSoundChoice.settingKey), 'notify');
    // The sheet stays up; the row behind it already reads the choice.
    expect(find.text('Notify'), findsNWidgets(2));
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await actOn(tester, 'Buy milk', 'Done');
    expect(device.donePlayed, [DoneSound.notify, DoneSound.notify]);
  });

  test('a saved choice is read back, and an unknown one falls back', () async {
    final settings = MemorySettingsStore();
    expect(await AppSounds.load(settings), isTrue);
    expect(await DoneSoundChoice.load(settings), DoneSound.complete);
    await settings.write(AppSounds.settingKey, 'off');
    await settings.write(DoneSoundChoice.settingKey, 'notify');
    expect(await AppSounds.load(settings), isFalse);
    expect(await DoneSoundChoice.load(settings), DoneSound.notify);
    await settings.write(DoneSoundChoice.settingKey, 'gong');
    expect(await DoneSoundChoice.load(settings), DoneSound.complete);
  });
}
