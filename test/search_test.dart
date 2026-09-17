import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/search.dart';
import 'package:remind_me/state/providers.dart';
import 'package:remind_me/state/recent_searches.dart';

import 'support/memory_settings_store.dart';
import 'support/memory_todo_store.dart';

void main() {
  // A Friday.
  final today = DateTime(2026, 9, 4).epochDay;

  group('a rule says where its showings are', () {
    test('a weekly rule names its next and last showing', () {
      final rule = RepeatRule.weekly(
        today - 30,
        RepeatRule.weekdayBit(DateTime.tuesday),
      );
      expect(rule.occurrenceOnOrAfter(today), today + 4);
      expect(rule.occurrenceBefore(today), today - 3);
      expect(rule.occurrenceOnOrAfter(today + 4), today + 4);
    });

    test('nothing before the start or after the end', () {
      final rule = RepeatRule.daily(today).copyWith(endDay: today + 2);
      expect(rule.occurrenceBefore(today), isNull);
      expect(rule.occurrenceOnOrAfter(today - 10), today);
      expect(rule.occurrenceOnOrAfter(today + 3), isNull);
      expect(rule.occurrenceBefore(today + 10), today + 2);
    });

    test('a custom rule reads its own days', () {
      final rule = RepeatRule.custom({today - 5, today + 2, today + 9});
      expect(rule.occurrenceOnOrAfter(today), today + 2);
      expect(rule.occurrenceBefore(today), today - 5);
      expect(rule.occurrenceOnOrAfter(today + 10), isNull);
    });
  });

  group('a match', () {
    test('is the query anywhere in the words, case aside', () {
      expect(matchesSearch('Call the Dentist', 'dent'), isTrue);
      expect(matchesSearch('Call the Dentist', 'DENTIST'), isTrue);
      expect(matchesSearch('Call the Dentist', ' dentist '), isTrue);
      expect(matchesSearch('Call the Dentist', 'doctor'), isFalse);
    });

    test('nothing answers to nothing', () {
      expect(matchesSearch('Anything', ''), isFalse);
      expect(matchesSearch('Anything', '   '), isFalse);
    });

    test('the LIKE pattern escapes the wildcards', () {
      expect(likePattern('50%'), r'%50\%%');
      expect(likePattern('a_b'), r'%a\_b%');
      expect(likePattern(r'c:\'), r'%c:\\%');
    });
  });

  group('the store searches every day', () {
    late MemoryTodoStore store;

    setUp(() => store = MemoryTodoStore());

    Future<List<String>> found(String query) async => [
      for (final hit in await store.search(query, today: today))
        '${hit.day - today}:${hit.todo.title}',
    ];

    test('one-offs are found on their days, latest first', () async {
      await store.insert(day: today - 3, title: 'Book the dentist');
      await store.insert(day: today + 5, title: 'Dentist at ten');
      await store.insert(day: today, title: 'Buy milk');

      expect(await found('dentist'), [
        '5:Dentist at ten',
        '-3:Book the dentist',
      ]);
      expect(await found('milk'), ['0:Buy milk']);
      expect(await found('nothing'), isEmpty);
      expect(await found(''), isEmpty);
    });

    test('a rule answers once, on its next showing', () async {
      await store.insertSeries(
        day: today - 10,
        title: 'Water the plants',
        rule: RepeatRule.weekly(
          today - 10,
          RepeatRule.weekdayBit(DateTime.monday),
        ),
      );
      // A showing written down carries the same words; it is not a second
      // answer.
      final showing = (await store.todosOn(today - 4)).single;
      await store.materialize(day: today - 4, todo: showing);

      final hits = await store.search('plants', today: today);
      expect(hits.single.day, today + 3);
      expect(hits.single.rule, isNotNull);
      expect(hits.single.todo.repeats, isTrue);
    });

    test('a rule that has run out answers on its last showing', () async {
      await store.insertSeries(
        day: today - 10,
        title: 'Take the course',
        rule: RepeatRule.daily(today - 10).copyWith(endDay: today - 2),
      );
      expect(await found('course'), ['-2:Take the course']);
    });

    test('a hidden showing does not answer', () async {
      final todo = await store.insert(day: today, title: 'Gone');
      await store.remove(day: today, todo: todo);
      expect(await found('gone'), isEmpty);
    });
  });

  group('recent searches', () {
    ProviderContainer boot(
      MemorySettingsStore settings, [
      List<String>? initial,
    ]) {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(settings),
          if (initial != null)
            initialRecentSearchesProvider.overrideWithValue(initial),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('are loaded from what was saved, and nothing from rubbish', () async {
      final saved = MemorySettingsStore({
        RecentSearches.settingKey: '["milk","dentist"]',
      });
      expect(await RecentSearches.load(saved), ['milk', 'dentist']);
      expect(await RecentSearches.load(MemorySettingsStore()), isEmpty);
      final rubbish = MemorySettingsStore({RecentSearches.settingKey: '{'});
      expect(await RecentSearches.load(rubbish), isEmpty);
    });

    test('the newest comes first, once, and only a few are kept', () async {
      final settings = MemorySettingsStore();
      final container = boot(settings);
      final recent = container.read(recentSearchesProvider.notifier);

      await recent.remember('milk');
      await recent.remember('dentist');
      await recent.remember('  Milk ');
      expect(container.read(recentSearchesProvider), ['Milk', 'dentist']);

      for (var i = 0; i < RecentSearches.keep + 2; i++) {
        await recent.remember('search $i');
      }
      final kept = container.read(recentSearchesProvider);
      expect(kept.length, RecentSearches.keep);
      expect(kept.first, 'search ${RecentSearches.keep + 1}');
      expect(kept, isNot(contains('Milk')));
      expect(await RecentSearches.load(settings), kept);
    });

    test('nothing is remembered for an empty search', () async {
      final container = boot(MemorySettingsStore(), ['milk']);
      await container.read(recentSearchesProvider.notifier).remember('  ');
      expect(container.read(recentSearchesProvider), ['milk']);
    });

    test('forgetting clears the list and the saved copy', () async {
      final settings = MemorySettingsStore();
      final container = boot(settings, ['milk']);
      await container.read(recentSearchesProvider.notifier).forget();
      expect(container.read(recentSearchesProvider), isEmpty);
      expect(await RecentSearches.load(settings), isEmpty);
    });
  });
}
