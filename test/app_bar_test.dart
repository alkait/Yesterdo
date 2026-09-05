import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/app_theme.dart';
import 'package:remind_me/state/providers.dart';
import 'package:remind_me/ui/branded/branded.dart';

import 'support/memory_settings_store.dart';

/// The bar gives its sides equal room and hands the middle what is left, so
/// a title too wide for that comes down in size instead of crowding them.
void main() {
  Widget barWith({required Widget center, Widget? leading, Widget? trailing}) =>
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          initialThemeChoiceProvider.overrideWithValue(AppThemeChoice.ink),
        ],
        child: BrandedApp(
          title: 'Yesterdo',
          home: BrandedScaffold(
            children: [
              BrandedAppBar(
                leading: leading,
                trailing: trailing,
                center: center,
              ),
            ],
          ),
        ),
      );

  /// A narrow phone, so the words have to be long rather than enormous.
  void narrowScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a title too wide for the bar shrinks clear of the buttons', (
    tester,
  ) async {
    narrowScreen(tester);
    const words = 'A heading with far too many words in it';
    await tester.pumpWidget(
      barWith(
        leading: BrandedTextButton(label: 'Cancel', onTap: () {}),
        trailing: BrandedTextButton(label: 'Save', onTap: () {}),
        center: const BrandedText(words, role: BrandedTextRole.title),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text(words));
    expect(
      title.width,
      lessThan(tester.getSize(find.text(words)).width),
      reason: 'drawn smaller than the words ask for',
    );
    expect(
      title.left,
      greaterThanOrEqualTo(tester.getRect(find.text('Cancel')).right),
    );
    expect(
      title.right,
      lessThanOrEqualTo(tester.getRect(find.text('Save')).left),
    );
  });

  testWidgets('a title that fits is left alone, on the centre line', (
    tester,
  ) async {
    narrowScreen(tester);
    await tester.pumpWidget(
      barWith(
        leading: BrandedTextButton(label: 'Back', onTap: () {}),
        center: const BrandedText('Task', role: BrandedTextRole.title),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('Task'));
    expect(
      title.width,
      closeTo(tester.getSize(find.text('Task')).width, 0.5),
      reason: 'not shrunk',
    );
    expect(
      title.center.dx,
      closeTo(tester.getRect(find.byType(BrandedAppBar)).center.dx, 0.5),
      reason: 'on the centre line with nothing on its right',
    );
  });
}
