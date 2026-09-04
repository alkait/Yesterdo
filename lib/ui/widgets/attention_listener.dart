import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../state/attention_request.dart';
import '../../state/providers.dart';
import 'attention_sheet.dart';

/// Answers a tapped notification. It turns the list to the task's day, and
/// once that day is on screen puts the attention sheet up over it, with the
/// card already at the top behind. A task gone by then is left alone.
class AttentionListener extends ConsumerStatefulWidget {
  const AttentionListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AttentionListener> createState() => _AttentionListenerState();
}

class _AttentionListenerState extends ConsumerState<AttentionListener> {
  @override
  void initState() {
    super.initState();
    // Fired at once as well, for a request raised before the first frame by
    // a notification that launched the app.
    ref.listenManual(
      attentionRequestProvider,
      (_, request) => _turnTo(request),
      fireImmediately: true,
    );
    ref.listenManual(todosProvider, (_, _) => _present());
  }

  /// Deferred to after the frame: a request can arrive while the tree is
  /// building, and neither a provider nor the navigator may be touched then.
  void _turnTo(AttentionRequest? request) {
    if (request == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(selectedDayProvider.notifier)
          .select(dateFromEpochDay(request.day));
      _present();
    });
  }

  /// Puts the sheet up if the requested day is loaded. Called again as the
  /// list changes, so a day still being read gets its turn.
  void _present() {
    if (!mounted) return;
    final request = ref.read(attentionRequestProvider);
    if (request == null) return;
    if (ref.read(selectedDayProvider).epochDay != request.day) return;
    // While a day is being read, the value on hand is still the last day's,
    // so the wait goes on until the read lands.
    final loaded = ref.read(todosProvider);
    if (loaded.isLoading || !loaded.hasValue) return;
    final todos = loaded.requireValue;

    ref.read(attentionRequestProvider.notifier).clear();
    for (final todo in todos) {
      if (todo.key != request.key) continue;
      // Whatever screen was open gives way to the list the sheet sits over.
      Navigator.of(context).popUntil((route) => route.isFirst);
      showAttentionSheet(context, ref, todo);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
