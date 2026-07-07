// Briefkist design system — metadata row with inline correction. Source: design/components/display/MetaRow.jsx

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

/// A label/value metadata row. When [editable] and [onSave] are set, a pencil
/// affordance switches the value to an inline text field: Enter or blur
/// commits (calling [onSave] only if the value changed), Escape cancels.
/// Corrected fields show a quiet "corrected" tick — never a warning color.
class MfMetaRow extends StatefulWidget {
  const MfMetaRow({
    super.key,
    required this.label,
    this.value,
    this.mono = false,
    this.corrected = false,
    this.editable = true,
    this.onSave,
    this.child,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final bool mono;
  final bool corrected;
  final bool editable;
  final ValueChanged<String>? onSave;

  /// Custom value widget; wins over [value] for display.
  final Widget? child;

  /// The 1px bottom hairline; suppress on the last row of a group.
  final bool showDivider;

  @override
  State<MfMetaRow> createState() => _MfMetaRowState();
}

class _MfMetaRowState extends State<MfMetaRow> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();

  bool _editing = false;
  bool _rowHovered = false;
  bool _editHovered = false;
  bool _editFocused = false;

  bool get _canEdit => widget.editable && widget.onSave != null;

  @override
  void initState() {
    super.initState();
    _fieldFocus.addListener(_onFieldFocusChange);
  }

  @override
  void dispose() {
    _fieldFocus.removeListener(_onFieldFocusChange);
    _fieldFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFieldFocusChange() {
    // Blur commits — unless Escape already cancelled (editing is false then).
    if (!_fieldFocus.hasFocus && _editing) _commit();
  }

  void _startEdit() {
    _controller.text = widget.value ?? '';
    setState(() => _editing = true);
  }

  void _commit() {
    if (!_editing) return;
    final draft = _controller.text;
    setState(() => _editing = false);
    if (draft != (widget.value ?? '')) widget.onSave?.call(draft);
  }

  void _cancel() {
    if (!_editing) return;
    setState(() => _editing = false);
  }

  bool get _touchPlatform {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: widget.showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: mf.border)),
            )
          : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _rowHovered = true),
        onExit: (_) => setState(() => _rowHovered = false),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  widget.label.toUpperCase(),
                  style: MfType.monoCaps.copyWith(color: mf.text3),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _editing ? _buildField(mf) : _buildValue(mf)),
            if (_canEdit && !_editing) ...[
              const SizedBox(width: 12),
              _buildEditButton(mf),
            ],
          ],
        ),
      ),
    );
  }

  Widget _correctedMark(MfColors mf) => Tooltip(
    message: 'Corrected by you',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MfIcon(MfGlyphs.check, size: 11, strokeWidth: 2.5, color: mf.ok),
        const SizedBox(width: 4),
        Text('corrected', style: MfType.monoXs.copyWith(color: mf.ok)),
      ],
    ),
  );

  Widget _buildValue(MfColors mf) {
    if (widget.child != null) {
      // Hug content: the value column's Expanded would otherwise stretch
      // inline children (chips) to the full column width — Chip.jsx is
      // inline-flex (QA finding, PR #32).
      final hugged = Align(
        alignment: AlignmentDirectional.centerStart,
        child: widget.child,
      );
      if (!widget.corrected) return hugged;
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          widget.child!,
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _correctedMark(mf),
          ),
        ],
      );
    }

    final hasValue = widget.value != null;
    final textStyle = !hasValue
        ? MfType.base.copyWith(color: mf.text3, fontStyle: FontStyle.italic)
        : widget.mono
        ? MfType.mono.copyWith(color: mf.text1)
        : MfType.base.copyWith(color: mf.text1);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.value ?? 'not detected', style: textStyle),
          if (widget.corrected)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _correctedMark(mf),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditButton(MfColors mf) {
    final visible =
        _touchPlatform || _rowHovered || _editHovered || _editFocused;
    // JSX gives the button `padding:6; margin:-4px 0` — the 27px button only
    // occupies 19px of row height. Emulate the negative margin by letting it
    // overflow its layout box 4px on top and bottom.
    return SizedBox(
      width: 27,
      height: 19,
      child: OverflowBox(
        maxWidth: 27,
        maxHeight: 27,
        alignment: Alignment.center,
        child: _editButtonInner(mf, visible),
      ),
    );
  }

  Widget _editButtonInner(MfColors mf, bool visible) {
    return Semantics(
      button: true,
      label: 'Edit ${widget.label}',
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: MfMotion.fast,
        curve: MfMotion.curve,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (h) => setState(() => _editHovered = h),
          onShowFocusHighlight: (f) => setState(() => _editFocused = f),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _startEdit();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: _startEdit,
            child: AnimatedContainer(
              duration: MfMotion.fast,
              curve: MfMotion.curve,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _editHovered
                    ? mf.surfaceHover
                    : mf.surfaceHover.withAlpha(0),
                borderRadius: BorderRadius.circular(MfRadius.md),
              ),
              // Focus ring inside the button bounds so layout never shifts.
              foregroundDecoration: _editFocused
                  ? BoxDecoration(
                      border: Border.all(color: mf.focusRing, width: 2),
                      borderRadius: BorderRadius.circular(MfRadius.md),
                    )
                  : null,
              child: MfIcon(
                MfGlyphs.pencil,
                size: 15,
                color: _editHovered ? mf.text1 : mf.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(MfColors mf) {
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MfRadius.md),
      borderSide: BorderSide(color: mf.borderStrong),
    );
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _controller,
        focusNode: _fieldFocus,
        autofocus: true,
        style: MfType.base.copyWith(color: mf.text1),
        cursorColor: mf.accent,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: mf.surfaceCard,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 10,
          ),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MfRadius.md),
            borderSide: BorderSide(color: mf.focusRing, width: 2),
          ),
        ),
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
