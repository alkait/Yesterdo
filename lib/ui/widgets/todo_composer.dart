import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../branded/branded.dart';

/// Always-visible entry row pinned to the bottom. Submitting keeps focus so
/// several tasks can be typed in a row.
class TodoComposer extends ConsumerStatefulWidget {
  const TodoComposer({super.key});

  @override
  ConsumerState<TodoComposer> createState() => _TodoComposerState();
}

class _TodoComposerState extends ConsumerState<TodoComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(todosProvider.notifier).add(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => BrandedBottomBar(
    child: Row(
      children: [
        const BrandedIcon(Icons.add_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: BrandedTextField(
            controller: _controller,
            focusNode: _focus,
            hint: 'Add a task',
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    ),
  );
}
