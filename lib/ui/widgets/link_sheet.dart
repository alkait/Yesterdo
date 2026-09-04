import 'package:flutter/material.dart';

import '../branded/branded.dart';

/// What the link sheet hands back: an address, or null to take the link
/// off. Wrapped so backing out can be told from removing.
class LinkPick {
  const LinkPick(this.url);

  final String? url;
}

/// Asks for a web address for the selected words. Returns the pick, or null
/// when the sheet is swiped away.
Future<LinkPick?> showLinkSheet(BuildContext context, {String? current}) =>
    showBrandedSheet<LinkPick>(
      context,
      (sheetContext) => _LinkSheet(current: current),
    );

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.current});

  final String? current;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final _controller = TextEditingController(text: widget.current ?? '')
    ..addListener(() => setState(() {}));
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Bare `example.com` is taken to mean the web.
  String get _url {
    final typed = _controller.text.trim();
    return typed.contains('://') ? typed : 'https://$typed';
  }

  @override
  Widget build(BuildContext context) => Padding(
    // Lifted clear of the keyboard, which the sheet itself sits under.
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandedTextField(
          key: const ValueKey('link-address'),
          controller: _controller,
          focusNode: _focus,
          hint: 'example.com',
          autofocus: true,
          onSubmitted: (_) => Navigator.of(context).pop(LinkPick(_url)),
        ),
        const BrandedDivider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.current != null)
              BrandedTextButton(
                label: 'Remove',
                tone: BrandedTone.danger,
                onTap: () => Navigator.of(context).pop(const LinkPick(null)),
              )
            else
              const SizedBox.shrink(),
            BrandedTextButton(
              label: 'Done',
              enabled: _controller.text.trim().isNotEmpty,
              onTap: () => Navigator.of(context).pop(LinkPick(_url)),
            ),
          ],
        ),
      ],
    ),
  );
}
