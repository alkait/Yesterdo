import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Material widgets that must never appear outside the brand kit. Each one
/// has a Branded equivalent that owns its look.
const _banned = <String, String>{
  r'\bText\(': 'BrandedText',
  r'\bIcon\(': 'BrandedIcon',
  r'\bTextField\(': 'BrandedTextField',
  r'\bDivider\(': 'BrandedDivider',
  r'\bScaffold\(': 'BrandedScaffold',
  r'\bAppBar\(': 'BrandedAppBar',
  r'\bDismissible\(': 'BrandedDismissible',
  r'\bMaterialApp\(': 'BrandedApp',
  r'\bMaterialPageRoute\(': 'openBrandedPage',
  r'\bReorderableListView\b': 'BrandedReorderableList',
  r'\bReorderableDragStartListener\b': 'BrandedDragLift',
  r'\bReorderableDelayedDragStartListener\b': 'BrandedDragLift',
  r'\bListView\.': 'BrandedReorderableList',
  r'showModalBottomSheet': 'showBrandedSheet',
  r'\bTextStyle\(': 'a BrandedTextRole',
  r'\bColors\.': 'a BrandedTone',
  r'\bColor\(0x': 'a colour in AppTheme',
  r'Theme\.of\(': 'a BrandedTone',
};

/// Screen files: everything under `lib/ui` except the brand kit itself,
/// plus the app root.
List<File> screenFiles() {
  final files = <File>[File('lib/app.dart')];
  for (final entity in Directory('lib/ui').listSync(recursive: true)) {
    final path = entity.path;
    if (entity is! File || !path.endsWith('.dart')) continue;
    if (path.contains('lib/ui/branded/')) continue;
    files.add(entity);
  }
  return files;
}

void main() {
  test('screens are built from Branded widgets only', () {
    final violations = <String>[];

    for (final file in screenFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final entry in _banned.entries) {
          if (RegExp(entry.key).hasMatch(line)) {
            violations.add(
              '${file.path}:${i + 1} uses a raw Material widget; '
              'use ${entry.value} instead\n    ${line.trim()}',
            );
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Every visual element goes through the brand kit so a change lands '
          'in one place:\n${violations.join('\n')}',
    );
  });

  test('the brand kit is reachable through one barrel import', () {
    final barrel = File('lib/ui/branded/branded.dart').readAsStringSync();
    final kit = Directory('lib/ui/branded')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.dart') && name != 'branded.dart');

    for (final name in kit) {
      expect(
        barrel,
        contains("export '$name';"),
        reason: '$name is missing from the branded barrel',
      );
    }
  });
}
