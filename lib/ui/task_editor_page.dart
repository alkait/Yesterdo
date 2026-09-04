import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/due.dart';
import '../data/repeat_rule.dart';
import '../data/rich/task_body.dart';
import '../state/providers.dart';
import '../state/task_draft.dart';
import 'branded/branded.dart';
import 'widgets/body_editor.dart';
import 'widgets/due_picker_sheet.dart';
import 'widgets/image_source_sheet.dart';
import 'widgets/link_sheet.dart';
import 'widgets/repeat_picker_sheet.dart';

/// The full screen where a task's words are written and its time and repeat
/// are chosen. Adding and editing both land here, and it hands the draft
/// back through the navigator. The words are styled in place, with the
/// format bar over the keyboard.
class TaskEditorPage extends ConsumerStatefulWidget {
  const TaskEditorPage({
    super.key,
    required this.heading,
    required this.anchorDay,
    this.initialBody,
    this.initialDue,
    this.initialRepeat,
  });

  final String heading;

  /// The day being looked at, which a new repeat rule starts from.
  final int anchorDay;

  final TaskBody? initialBody;
  final Due? initialDue;
  final RepeatRule? initialRepeat;

  @override
  ConsumerState<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends ConsumerState<TaskEditorPage> {
  final _editor = GlobalKey<BodyEditorState>();
  late TaskBody _body = widget.initialBody ?? TaskBody.plain('');
  late Due? _due = widget.initialDue;
  late RepeatRule? _repeat = widget.initialRepeat;
  Animation<double>? _arrival;

  /// Whether there is anything to save. Save stays greyed until there is.
  bool get _hasWords => _body.hasWords;

  /// The keyboard is asked for only once the screen has finished sliding
  /// in. Raised during the transition, it fights the slide and the whole
  /// thing judders. The route's animation is read after the first frame,
  /// since during the first build it has not yet been started.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusOnArrival());
  }

  void _focusOnArrival() {
    if (!mounted) return;
    final arrival = ModalRoute.of(context)?.animation;
    if (arrival == null || arrival.isCompleted) {
      _editor.currentState?.focusEnd();
      return;
    }
    _arrival = arrival..addStatusListener(_onArrival);
  }

  void _onArrival(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _arrival?.removeStatusListener(_onArrival);
    if (mounted) _editor.currentState?.focusEnd();
  }

  @override
  void dispose() {
    _arrival?.removeStatusListener(_onArrival);
    super.dispose();
  }

  void _onBodyChanged(TaskBody body) => setState(() => _body = body);

  void _cancel() => Navigator.of(context).pop();

  void _save() {
    if (!_hasWords) return;
    Navigator.of(context)
        .pop(TaskDraft(body: _body, due: _due, repeat: _repeat));
  }

  Future<void> _pickDue() async {
    final pick = await showDuePicker(context, current: _due);
    if (!mounted || pick == null) return;
    setState(() => _due = pick.due);
    if (pick.due case final due?) {
      await ref.read(lastSoundProvider.notifier).remember(due.sound);
      // The system is asked the first time a reminder is wanted, not at
      // launch, so the ask arrives with its reason in view.
      if (due.hasReminder) {
        await ref.read(reminderSchedulerProvider).requestPermission();
      }
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

  Future<void> _pickImage() async {
    final origin = await showImageSourceSheet(context);
    if (!mounted || origin == null) return;
    final image = await fetchImage(ref.read(deviceBridgeProvider), origin);
    if (!mounted || image == null) return;
    _editor.currentState?.insertImage(image);
  }

  Future<void> _pickLink() async {
    final editor = _editor.currentState;
    if (editor == null) return;
    final pick = await showLinkSheet(context, current: editor.currentLink);
    if (!mounted || pick == null) return;
    editor.setLink(pick.url);
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor.currentState;
    return BrandedScaffold(
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
                BodyEditor(
                  key: _editor,
                  initial: _body,
                  imagesDirectory: ref.watch(imagesDirectoryProvider),
                  hint: 'What needs doing?',
                  onChanged: _onBodyChanged,
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
                      ? _due!.remindersLabel(
                          twentyFourHour: MediaQuery.alwaysUse24HourFormatOf(
                            context,
                          ),
                        )
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
        BrandedFormatBar(
          current: editor?.currentStyles,
          checklist: editor?.focusedIsChecklist ?? false,
          onBold: () => editor?.toggleBold(),
          onItalic: () => editor?.toggleItalic(),
          onUnderline: () => editor?.toggleUnderline(),
          onHighlight: () => editor?.cycleHighlight(),
          onLink: _pickLink,
          onChecklist: () => editor?.toggleChecklist(),
          onImage: _pickImage,
        ),
      ],
    );
  }
}
