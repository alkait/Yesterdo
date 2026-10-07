import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_labels.dart';
import '../core/day.dart';
import '../data/due.dart';
import '../data/repeat_rule.dart';
import '../data/rich/task_body.dart';
import '../state/providers.dart';
import '../state/task_draft.dart';
import 'branded/branded.dart';
import 'widgets/arrival_focus.dart';
import 'widgets/body_editor.dart';
import 'widgets/image_source_sheet.dart';
import 'widgets/link_sheet.dart';
import 'widgets/month_picker_sheet.dart';
import 'widgets/reminder_picker_sheet.dart';
import 'widgets/repeat_picker_sheet.dart';
import 'widgets/time_picker_sheet.dart';

/// The full screen where a task's words are written, its time and repeat
/// are chosen, it is pinned or let go, and it is set to carry itself over
/// or not. Adding and editing both land here, and it hands the draft
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
    this.initialPinned = false,
    this.initialCarryOver = false,
    this.pinnable = true,
  });

  final String heading;

  /// The day being looked at, which a new repeat rule starts from.
  final int anchorDay;

  final TaskBody? initialBody;
  final Due? initialDue;
  final RepeatRule? initialRepeat;
  final bool initialPinned;
  final bool initialCarryOver;

  /// Whether a pin, and with it carrying over, is offered. A done task has
  /// neither to offer.
  final bool pinnable;

  @override
  ConsumerState<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends ConsumerState<TaskEditorPage> {
  final _editor = GlobalKey<BodyEditorState>();
  late TaskBody _body = widget.initialBody ?? TaskBody.plain('');

  /// The day the task will sit on. A new one starts on the day being looked
  /// at, which is today unless the list has been turned.
  late int _day = widget.anchorDay;
  late Due? _due = widget.initialDue;
  late RepeatRule? _repeat = widget.initialRepeat;
  late bool _pinned = widget.initialPinned;
  late bool _carryOver = widget.initialCarryOver;
  late final _arrival = ArrivalFocus(_focusEditor);

  /// Whether there is anything to save. Save stays greyed until there is.
  bool get _hasWords => _body.hasWords;

  /// The keyboard is asked for only once the screen has finished sliding
  /// in, at the end of the words.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _arrival.arm(context);
    });
  }

  void _focusEditor() {
    if (mounted) _editor.currentState?.focusEnd();
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  void _onBodyChanged(TaskBody body) => setState(() => _body = body);

  void _cancel() => Navigator.of(context).pop();

  void _save() {
    if (!_hasWords) return;
    Navigator.of(context).pop(
      TaskDraft(
        day: _day,
        body: _body,
        due: _due,
        repeat: _repeat,
        pinned: _pinned,
        // A repeating task comes back on its own, so it carries nothing.
        carryOver: _repeat == null && _carryOver,
      ),
    );
  }

  /// A fresh time carries no reminder yet, and the sound chosen last time,
  /// so a reminder added after starts from it. A cleared time takes its
  /// reminders with it, since they hang off it.
  Future<void> _pickTime() async {
    final pick = await showTimeSheet(context, current: _due?.minute);
    if (!mounted || pick == null) return;
    setState(
      () => _due = switch (pick.minute) {
        null => null,
        final minute =>
          _due?.copyWith(minute: minute) ??
              Due(minute: minute, sound: ref.read(lastSoundProvider)),
      },
    );
  }

  Future<void> _pickReminder() async {
    final due = _due;
    if (due == null) return;
    final chosen = await showReminderSheet(context, current: due);
    if (!mounted || chosen == null) return;
    setState(() => _due = chosen);
    await ref.read(lastSoundProvider.notifier).remember(chosen.sound);
    // The system is asked the first time a reminder is wanted, not at
    // launch, so the ask arrives with its reason in view.
    if (chosen.hasReminder) {
      await ref.read(reminderSchedulerProvider).requestPermission();
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDayPicker(
      context,
      selected: dateFromEpochDay(_day),
      isAllowed: (_) => true,
    );
    if (!mounted || picked == null) return;
    setState(() => _day = picked.epochDay);
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
                // A repeating task takes its days from its rule, so there is
                // no one day to set here.
                if (_repeat == null) ...[
                  BrandedFieldRow(
                    label: 'Date',
                    icon: Icons.calendar_today_outlined,
                    value: dayHeadline(
                      dateFromEpochDay(_day),
                      now: ref.watch(clockProvider)(),
                    ),
                    detail: longDate(dateFromEpochDay(_day)),
                    onTap: _pickDay,
                  ),
                  const BrandedDivider(),
                ],
                BrandedFieldRow(
                  label: 'Time',
                  icon: Icons.schedule_outlined,
                  value:
                      _due?.label(
                        twentyFourHour: MediaQuery.alwaysUse24HourFormatOf(
                          context,
                        ),
                      ) ??
                      'None',
                  onTap: _pickTime,
                ),
                const BrandedDivider(),
                // A reminder hangs off the time, so until there is one the
                // row only says so.
                BrandedFieldRow(
                  label: 'Reminder',
                  icon: Icons.notifications_none_rounded,
                  value: switch (_due) {
                    null => 'Set a time first',
                    final due when due.hasReminder => due.remindersLabel(
                      twentyFourHour: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                    _ => 'None',
                  },
                  onTap: _due == null ? null : _pickReminder,
                ),
                const BrandedDivider(),
                BrandedFieldRow(
                  label: 'Repeat',
                  icon: Icons.repeat_rounded,
                  value: _repeat?.label ?? 'Never',
                  detail: _repeat?.detail,
                  onTap: _pickRepeat,
                ),
                if (widget.pinnable) ...[
                  const BrandedDivider(),
                  BrandedToggleRow(
                    key: const ValueKey('pin-row'),
                    label: 'Pin',
                    icon: Icons.push_pin_outlined,
                    value: _pinned,
                    onChanged: (value) => setState(() => _pinned = value),
                  ),
                  // A repeating task comes back on its own, so like the Date
                  // row this one has nothing to say for it.
                  if (_repeat == null) ...[
                    const BrandedDivider(),
                    BrandedToggleRow(
                      key: const ValueKey('carry-row'),
                      label: 'Carry over',
                      icon: Icons.arrow_forward_rounded,
                      detail: 'Moves to today if left undone',
                      value: _carryOver,
                      onChanged: (value) => setState(() => _carryOver = value),
                    ),
                  ],
                ],
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
