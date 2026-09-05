import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../branded/branded.dart';
import '../backlog_page.dart';

/// A quiet line above today's cards saying how much was left undone on
/// earlier days. There is nothing when there is nothing left. Tapping it
/// opens the list on its own screen.
class BacklogRow extends ConsumerWidget {
  const BacklogRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(backlogProvider).value?.count ?? 0;
    if (count == 0) return const SizedBox.shrink();
    // The card brings its own gutter and half a gap, like the ones below.
    return BrandedCard(
      key: const ValueKey('backlog-row'),
      recessed: true,
      onTap: () => openBrandedPage<void>(context, (_) => const BacklogPage()),
      leading: const BrandedIcon(
        Icons.history_rounded,
        tone: BrandedTone.muted,
      ),
      trailing: const BrandedIcon(
        Icons.chevron_right_rounded,
        tone: BrandedTone.muted,
      ),
      child: BrandedText(
        count == 1
            ? '1 left from an earlier day'
            : '$count left from earlier days',
        role: BrandedTextRole.label,
        tone: BrandedTone.muted,
      ),
    );
  }
}
