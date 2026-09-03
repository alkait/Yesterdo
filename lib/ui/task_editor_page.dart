import 'package:flutter/material.dart';

import 'branded/branded.dart';

/// The full screen where a task's text is written. Adding and editing both
/// land here, and it hands the finished text back through the navigator.
class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    required this.heading,
    this.initialText = '',
  });

  final String heading;
  final String initialText;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final _controller = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop();

  void _save() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) => BrandedScaffold(
    children: [
      BrandedAppBar(
        leading: BrandedTextButton(
          label: 'Cancel',
          onTap: _cancel,
          tone: BrandedTone.muted,
        ),
        center: BrandedText(
          widget.heading,
          role: BrandedTextRole.title,
          align: TextAlign.center,
        ),
        trailing: BrandedTextButton(label: 'Save', onTap: _save),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Brand.gutter,
            vertical: 8,
          ),
          child: BrandedTextField(
            controller: _controller,
            focusNode: _focus,
            hint: 'What needs doing?',
            autofocus: true,
            multiline: true,
          ),
        ),
      ),
    ],
  );
}
