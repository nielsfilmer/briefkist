// my-flopy design system — text field. Source: design/components/inputs/TextField.jsx

import 'package:flutter/material.dart';

import '../mf_theme.dart';

/// Labelled text input. 40px tall (multiline: 3 rows), radius 6, 1px strong
/// border (error tone when [error]), card surface. Focus shows the 2px plum
/// ring with the border going transparent, exactly like the mirror.
class MfTextField extends StatelessWidget {
  const MfTextField({
    super.key,
    this.label,
    this.message,
    this.error = false,
    this.mono = false,
    this.multiline = false,
    this.controller,
    this.onChanged,
    this.value,
  });

  final String? label;
  final String? message;
  final bool error;
  final bool mono;
  final bool multiline;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Initial value, used only when no [controller] is given.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: MfType.sm.copyWith(
              fontWeight: FontWeight.w600,
              color: mf.text2,
            ),
          ),
          const SizedBox(height: 6),
        ],
        _FieldInput(
          error: error,
          mono: mono,
          multiline: multiline,
          controller: controller,
          onChanged: onChanged,
          value: value,
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            style: MfType.sm.copyWith(color: error ? mf.err : mf.text3),
          ),
        ],
      ],
    );
  }
}

class _FieldInput extends StatefulWidget {
  const _FieldInput({
    required this.error,
    required this.mono,
    required this.multiline,
    this.controller,
    this.onChanged,
    this.value,
  });

  final bool error;
  final bool mono;
  final bool multiline;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? value;

  @override
  State<_FieldInput> createState() => _FieldInputState();
}

class _FieldInputState extends State<_FieldInput> {
  final FocusNode _focusNode = FocusNode();
  TextEditingController? _internal;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    if (widget.controller == null && widget.value != null) {
      _internal = TextEditingController(text: widget.value);
    }
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(_FieldInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _internal != null) {
      _internal!.dispose();
      _internal = null;
    }
  }

  @override
  void dispose() {
    _internal?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final style = (widget.mono ? MfType.mono : MfType.base)
        .copyWith(color: mf.text1);
    final decoration = BoxDecoration(
      color: mf.surfaceCard,
      borderRadius: BorderRadius.circular(MfRadius.md),
      border: Border.all(
        color: _focused
            ? Colors.transparent
            : (widget.error ? mf.err : mf.borderStrong),
      ),
    );

    final field = TextField(
      controller: widget.controller ?? _internal,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      minLines: widget.multiline ? 3 : 1,
      maxLines: widget.multiline ? 3 : 1,
      style: style,
      cursorColor: mf.accent,
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
      ),
    );

    return _FocusRing(
      focused: _focused,
      radius: MfRadius.md,
      child: widget.multiline
          ? Container(
              decoration: decoration,
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: field,
            )
          : Container(
              height: 40,
              decoration: decoration,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: field),
            ),
    );
  }
}

/// 2px plum focus ring drawn just outside the control (mirror: `outline: 2px
/// solid var(--focus-ring); outline-offset: 1px`).
class _FocusRing extends StatelessWidget {
  const _FocusRing({
    required this.focused,
    required this.radius,
    required this.child,
  });

  final bool focused;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (focused)
          Positioned(
            left: -3,
            top: -3,
            right: -3,
            bottom: -3,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 3),
                  border: Border.all(color: context.mf.focusRing, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
