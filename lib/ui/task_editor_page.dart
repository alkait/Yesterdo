import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/due.dart';
import '../data/repeat_rule.dart';
import '../state/providers.dart';
import '../state/task_draft.dart';
import 'branded/branded.dart';
import 'widgets/due_picker_sheet.dart';
import 'widgets/repeat_picker_sheet.dart';

/// The full screen where a task's words are written and its time and repeat
/// are chosen. Adding and editing both land here, and it hands the draft
/// back through the navigator.
class TaskEditorPage extends ConsumerStatefulWidget {
  const TaskEditorPage({
    super.key,
    required this.heading,
    required this.anchorDay,
    this.initialText = '',
    this.initialDue,
    this.initialRepeat,
  });

  final String heading;

  /// The day being looked at, which a new repeat rule starts from.
  final int anchorDay;

  final String initialText;
  final Due? initialDue;
  final RepeatRule? initialRepeat;

  @override
  ConsumerState<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends ConsumerState<TaskEditorPage> {
  late final _controller = TextEditingController(text: widget.initialText)
    ..addListener(_onTextChanged);
  final _focus = FocusNode();
  late Due? _due = widget.initialDue;
  late RepeatRule? _repeat = widget.initialRepeat;

  /// Whether there is anything to save. Save stays greyed until there is.
  bool get _hasWords => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _cancel() => Navigator.of(context).pop();

  void _save() {
    if (!_hasWords) return;
    Navigator.of(context).pop(
      TaskDraft(title: _controller.text.trim(), due: _due, repeat: _repeat),
    );
  }

  Future<void> _pickDue() async {
    final pick = await showDuePicker(context, current: _due);
    if (!mounted || pick == null) return;
    setState(() => _due = pick.due);
    // The system is asked the first time a reminder is wanted, not at
    // launch, so the ask arrives with its reason in view.
    if (pick.due?.hasReminder ?? false) {
      await ref.read(reminderSchedulerProvider).requestPermission();
    }
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
        leading: BrandedTextButton(label: 'Cancel', onTap: _cancel),
        center: BrandedText(
          widget.heading,
          role: BrandedTextRole.title,
          align: TextAlign.center,
        ),
        trailing: BrandedTextButton(
          label: 'Save',
          onTap: _save,
          enabled: _hasWords,
        ),
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
                label: 'Due',
                value:
                    _due?.label(
                      twentyFourHour: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ) ??
                    'None',
                detail: _due?.hasReminder ?? false
                    ? Due.reminderLabel(_due!.reminder)
                    : null,
                onTap: _pickDue,
              ),
              const BrandedDivider(),
              BrandedFieldRow(
                label: 'Repeat',
                value: _repeat?.label ?? 'Never',
                detail: _repeat?.detail,
                onTap: _pickRepeat,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
