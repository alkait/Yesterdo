import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/text_size.dart';
import 'package:remind_me/state/text_size_choice.dart';

import 'app_flow_test.dart' show addTask, bootApp;
import 'support/memory_settings_store.dart';

/// How large the words are drawn: a setting of the app's own, so a Mac,
/// which has no per-app text size for an iPad app, gets one too.
void main() {
  test('a saved size is loaded by name', () async {
    final store = MemorySettingsStore({TextSizeChoice.settingKey: 'larger'});
    expect(await TextSizeChoice.load(store), AppTextSize.larger);
  });

  test('nothing saved, or a name no longer known, is the default', () async {
    expect(await TextSizeChoice.load(MemorySettingsStore()), AppTextSize.standard);
    final stale = MemorySettingsStore({TextSizeChoice.settingKey: 'huge'});
    expect(await TextSizeChoice.load(stale), AppTextSize.standard);
    expect(AppTextSize.fallback.factor, 1.0);
  });

  testWidgets('a larger size grows the words, the icons and the rows to fit', (
    tester,
  ) async {
    final settings = MemorySettingsStore();
    await tester.pumpWidget(bootApp(settings: settings));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    double textHeight() => tester.getSize(find.text('Buy milk')).height;
    double gearSize() =>
        tester.getSize(find.byIcon(Icons.settings_outlined)).width;
    final cardBefore = tester.getSize(find.text('Buy milk')).height;
    final gearBefore = gearSize();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsOneWidget, reason: 'the row reads it');
    await tester.tap(find.byKey(const ValueKey('settings-text-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('text-size-largest')));
    await tester.pumpAndSettle();
    expect(await settings.read(TextSizeChoice.settingKey), 'largest');
    // The sheet stays up and already reads larger; the row behind it too.
    expect(find.text('Largest'), findsNWidgets(2));
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(textHeight(), closeTo(cardBefore * AppTextSize.largest.factor, 1));
    expect(gearSize(), closeTo(gearBefore * AppTextSize.largest.factor, 0.5));
  });

  testWidgets('the system\'s own size still counts underneath', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    final scaled = tester.getSize(find.text('Buy milk')).height;

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();
    final plain = tester.getSize(find.text('Buy milk')).height;
    expect(scaled, closeTo(plain * 1.2, 1));
  });
}
