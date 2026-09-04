import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Reads the day again when the app comes back to the front. Time has
/// passed, so a task may have fallen due meanwhile, and the notifications
/// laid down for the coming days are topped up.
class WakeRefresh extends ConsumerStatefulWidget {
  const WakeRefresh({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WakeRefresh> createState() => _WakeRefreshState();
}

class _WakeRefreshState extends ConsumerState<WakeRefresh>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(todosProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
