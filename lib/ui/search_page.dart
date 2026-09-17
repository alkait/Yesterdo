import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_labels.dart';
import '../core/day.dart';
import '../data/search.dart';
import '../state/providers.dart';
import 'branded/branded.dart';
import 'widgets/arrival_focus.dart';

/// Every day searched at once, on a screen of its own. Results come as the
/// words are typed, latest day first, and tapping one turns the list to
/// that day. With nothing typed, the last few searches are offered to run
/// again. A search is remembered when it is submitted or a result opened.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final _arrival = ArrivalFocus(_focus.requestFocus);

  /// What is being looked for, trimmed. Empty shows the recent searches.
  String _query = '';

  /// The last results read, kept up while the next read is on its way so
  /// the list does not blink between keystrokes.
  List<SearchHit> _hits = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTyped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _arrival.arm(context);
    });
  }

  @override
  void dispose() {
    _arrival.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTyped() {
    final query = _controller.text.trim();
    if (query == _query) return;
    setState(() {
      _query = query;
      if (query.isEmpty) _hits = const [];
    });
  }

  void _clear() {
    _controller.clear();
    _focus.requestFocus();
  }

  /// Runs a remembered search again, and brings it to the front.
  void _searchAgain(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focus.unfocus();
    ref.read(recentSearchesProvider.notifier).remember(query);
  }

  void _submit(String _) =>
      ref.read(recentSearchesProvider.notifier).remember(_query);

  /// Turns the list to the day the task is on, asks for the card to be
  /// pointed out there, and goes back to it.
  void _open(SearchHit hit) {
    ref.read(recentSearchesProvider.notifier).remember(_query);
    ref.read(spotlightProvider.notifier).raise(hit.day, hit.todo.key);
    ref.read(selectedDayProvider.notifier).select(dateFromEpochDay(hit.day));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_query.isNotEmpty) {
      final loaded = ref.watch(searchResultsProvider(_query));
      if (loaded.hasValue) _hits = loaded.requireValue;
    }
    final now = ref.watch(clockProvider)();

    return BrandedScaffold(
      children: [
        BrandedAppBar(
          leading: BrandedTextButton(
            label: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          center: const BrandedText(
            'Search',
            role: BrandedTextRole.title,
            align: TextAlign.center,
          ),
        ),
        _SearchField(
          controller: _controller,
          focus: _focus,
          onSubmitted: _submit,
          onClear: _query.isEmpty ? null : _clear,
        ),
        const BrandedDivider(),
        Expanded(
          child: _query.isEmpty
              ? _RecentSearches(
                  searches: ref.watch(recentSearchesProvider),
                  onTap: _searchAgain,
                  onClear: ref.read(recentSearchesProvider.notifier).forget,
                )
              : _Results(hits: _hits, now: now, onOpen: _open),
        ),
      ],
    );
  }
}

/// The words to look for, with a magnifier ahead of them and, once there
/// is something typed, a way to clear it.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Brand.gutter),
    child: Row(
      children: [
        const BrandedIcon(Icons.search_rounded),
        const SizedBox(width: Brand.gap),
        Expanded(
          child: BrandedTextField(
            controller: controller,
            focusNode: focus,
            hint: 'Find a task',
            search: true,
            onSubmitted: onSubmitted,
          ),
        ),
        if (onClear case final clear?)
          BrandedIconButton(
            icon: Icons.close_rounded,
            label: 'Clear search',
            size: BrandedIconSize.medium,
            onTap: clear,
          ),
      ],
    ),
  );
}

/// The last few searches, newest first, each a row that runs it again.
/// Nothing at all until there has been one.
class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.onTap,
    required this.onClear,
  });

  final List<String> searches;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: Brand.gutter,
        vertical: Brand.gap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: BrandedText(
                  'Recent',
                  role: BrandedTextRole.caption,
                  tone: BrandedTone.muted,
                ),
              ),
              BrandedTextButton(
                label: 'Clear',
                tone: BrandedTone.muted,
                onTap: onClear,
              ),
            ],
          ),
          for (final search in searches)
            BrandedOptionRow(
              key: ValueKey('recent-$search'),
              icon: Icons.history_rounded,
              label: search,
              onTap: () => onTap(search),
            ),
        ],
      ),
    );
  }
}

/// What answered, one card each, or a word to say nothing did.
class _Results extends StatelessWidget {
  const _Results({required this.hits, required this.now, required this.onOpen});

  final List<SearchHit> hits;
  final DateTime now;
  final ValueChanged<SearchHit> onOpen;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return const Center(
        child: BrandedText('Nothing found', tone: BrandedTone.muted),
      );
    }
    // The same list the day uses, so the cards sit as they do there.
    // Nothing is lifted: there is no drag lift.
    return BrandedReorderableList(
      itemCount: hits.length,
      onReorder: (_, _) {},
      itemBuilder: (context, index) {
        final hit = hits[index];
        return _HitCard(
          key: ValueKey('hit-${hit.key}'),
          hit: hit,
          detail: searchHitDetail(hit, now: now),
          onTap: () => onOpen(hit),
        );
      },
    );
  }
}

/// The small print under a result: the day, said the way the list heads it
/// when it is near, and dated otherwise; how it repeats, for a rule; and
/// whether it is done.
String searchHitDetail(SearchHit hit, {required DateTime now}) {
  final date = dateFromEpochDay(hit.day);
  final offset = hit.day - now.epochDay;
  final day = switch (offset) {
    0 || -1 || 1 => dayHeadline(date, now: now),
    _ => longDate(date),
  };
  return [
    if (hit.todo.done) 'Done',
    if (hit.rule case final rule?) rule.label,
    day,
  ].join(' · ');
}

class _HitCard extends StatelessWidget {
  const _HitCard({
    super.key,
    required this.hit,
    required this.detail,
    required this.onTap,
  });

  final SearchHit hit;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = hit.todo.done;
    return BrandedCard(
      recessed: done,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandedText(
            hit.todo.firstLine,
            role: BrandedTextRole.card,
            tone: done ? BrandedTone.muted : BrandedTone.primary,
            maxLines: Brand.cardLines,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (hit.rule != null) ...[
                  const BrandedIcon(
                    Icons.repeat_rounded,
                    size: BrandedIconSize.small,
                    tone: BrandedTone.muted,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: BrandedText(
                    detail,
                    role: BrandedTextRole.caption,
                    tone: BrandedTone.muted,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
