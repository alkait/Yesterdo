import 'package:flutter/material.dart';

import '../data/repeat_rule.dart';
import '../state/task_draft.dart';
import 'branded/branded.dart';
import 'widgets/repeat_picker_sheet.dart';

/// The full screen where a task's words are written and its repeat is chosen.
/// Adding and editing both land here, and it hands the draft back through the
/// navigator.
class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    required this.heading,
    required this.anchorDay,
    this.initialText = '',
    this.initialRepeat,
  });

  final String heading;

  /// The day being looked at, which a new repeat rule starts from.
  final int anchorDay;

  final String initialText;
  final RepeatRule? initialRepeat;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final _controller = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  late RepeatRule? _repeat = widget.initialRepeat;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop();

  void _save() {
    final text = _controller.text.trim();
    Navigator.of(context)
        .pop(text.isEmpty ? null : TaskDraft(title: text, repeat: _repeat));
  }

  Future<void> _pickRepeat() async {
    final chosen = await showRepeatPicker(
      context,
      anchorDay: widget.anchorDay,
      current: _repeat,
    );
    if (!mounted) return;
    setState(() => _repeat = chosen);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandedTextField(
                controller: _controller,
                focusNode: _focus,
                hint: 'What needs doing?',
                autofocus: true,
                multiline: true,
              ),
              const BrandedDivider(),
              BrandedFieldRow(
                label: 'Repeat',
                value: _repeat?.label ?? 'Never',
                onTap: _pickRepeat,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
