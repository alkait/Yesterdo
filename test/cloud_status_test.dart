import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/sync/cloud_status.dart';

import 'app_flow_test.dart' show addTask, at, bootApp;
import 'support/memory_cloud.dart';

/// Where the sync stands, as Settings reads it.
void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('before anything has run, Settings says so', (tester) async {
    await tester.pumpWidget(
      bootApp(cloud: MemoryCloudTransport(MemoryCloud())),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.text('iCloud'), findsOneWidget);
    expect(find.text('Never synced'), findsOneWidget);
    expect(find.text('Nothing has been sent yet.'), findsOneWidget);
  });

  testWidgets('without an iCloud account, Settings says to sign in', (
    tester,
  ) async {
    final cloud = MemoryCloudTransport(MemoryCloud(), signedIn: false);
    await tester.pumpWidget(bootApp(cloud: cloud));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    await openSettings(tester);

    expect(find.text('Not signed in'), findsOneWidget);
    expect(
      find.text('Sign into iCloud in Settings to sync between devices.'),
      findsOneWidget,
    );
  });

  testWidgets('after a write goes through, Settings is up to date', (
    tester,
  ) async {
    final cloud = MemoryCloudTransport(MemoryCloud());
    await tester.pumpWidget(bootApp(cloud: cloud, clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    await openSettings(tester);

    expect(cloud.pushes, 1);
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('Last synced just now.'), findsOneWidget);
  });

  testWidgets('a failed send is waiting, with the error for developers', (
    tester,
  ) async {
    final cloud = MemoryCloudTransport(MemoryCloud())..failNextPush = true;
    await tester.pumpWidget(bootApp(cloud: cloud, developer: true));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    await openSettings(tester);

    expect(find.text('Waiting to send'), findsOneWidget);
    expect(
      find.text('1 change to send. Will retry when online.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-icloud-error')), findsOneWidget);
    expect(find.textContaining('no network'), findsOneWidget);
  });

  testWidgets('the error is kept from everyone else', (tester) async {
    final cloud = MemoryCloudTransport(MemoryCloud())..failNextPush = true;
    await tester.pumpWidget(bootApp(cloud: cloud));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    await openSettings(tester);

    expect(find.text('Waiting to send'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-icloud-error')), findsNothing);
  });

  test('the words for each phase', () {
    final now = DateTime(2026, 10, 8, 9, 30);
    expect(const CloudStatus().label, 'Never synced');
    expect(
      const CloudStatus(phase: CloudPhase.syncing, pending: 3).detail(now),
      'Sending 3 changes…',
    );
    expect(
      const CloudStatus(phase: CloudPhase.syncing).detail(now),
      'Checking for changes…',
    );
    expect(
      CloudStatus(
        phase: CloudPhase.upToDate,
        lastSyncedAt: now.subtract(const Duration(minutes: 2)),
      ).detail(now),
      'Last synced 2 min ago.',
    );
    expect(
      const CloudStatus(phase: CloudPhase.waiting, pending: 1).detail(now),
      '1 change to send. Will retry when online.',
    );
  });

  test('how long ago, in words', () {
    final now = DateTime(2026, 10, 8, 9, 30);
    expect(agoLabel(now, now: now), 'just now');
    expect(
      agoLabel(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      agoLabel(now.subtract(const Duration(hours: 1)), now: now),
      '1 hour ago',
    );
    expect(
      agoLabel(now.subtract(const Duration(hours: 3)), now: now),
      '3 hours ago',
    );
    expect(agoLabel(DateTime(2026, 10, 7, 23), now: now), 'yesterday');
    expect(agoLabel(DateTime(2026, 10, 1, 9), now: now), 'on Oct 1');
  });
}
