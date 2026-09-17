import 'repeat_rule.dart';
import 'todo.dart';

/// One answer to a search: a task and the day it is looked for on. A rule
/// answers once, as its showing on the day nearest today, and carries the
/// rule so the result can say how it repeats.
class SearchHit {
  const SearchHit({required this.day, required this.todo, this.rule});

  final int day;
  final Todo todo;
  final RepeatRule? rule;

  /// Stable across reads, for widget keys.
  String get key => '$day:${todo.key}';
}

/// Whether [words] answer to [query]: the query anywhere in them, case
/// aside. The one place a match is decided. A store may narrow what it
/// reads before asking this, but never lets through more than this does.
bool matchesSearch(String words, String query) {
  final wanted = query.trim().toLowerCase();
  return wanted.isNotEmpty && words.toLowerCase().contains(wanted);
}

/// The query as a SQL `LIKE` pattern, for a store that narrows its read to
/// rows that could match: the query anywhere, with its own wildcards
/// escaped by [likeEscape].
String likePattern(String query) {
  final escaped = query
      .trim()
      .replaceAll(likeEscape, '$likeEscape$likeEscape')
      .replaceAll('%', '$likeEscape%')
      .replaceAll('_', '${likeEscape}_');
  return '%$escaped%';
}

const likeEscape = r'\';

/// Latest day first, so what is to come heads the list and the past trails
/// off below today. Within a day, the day's own order.
int compareSearchHits(SearchHit a, SearchHit b) {
  final byDay = b.day.compareTo(a.day);
  return byDay != 0 ? byDay : compareTodos(a.todo, b.todo);
}

/// What a search answers with: one-offs on their days, and each rule once,
/// on its next showing from [today], or its last one when it has run out.
/// Latest day first.
List<SearchHit> composeSearch({
  required List<SearchHit> oneOffs,
  required List<Recurrence> recurrences,
  required int today,
}) => [
  ...oneOffs,
  for (final each in recurrences)
    SearchHit(
      day:
          each.rule.occurrenceOnOrAfter(today) ??
          each.rule.occurrenceBefore(today) ??
          each.rule.startDay,
      todo: Todo.projected(each),
      rule: each.rule,
    ),
]..sort(compareSearchHits);
