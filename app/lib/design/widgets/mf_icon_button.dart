// my-flopy design system — icon button. Source: design/components/actions/IconButton.jsx
//
// Square, transparent, quiet: text-2 icon on nothing; hover = one paper step
// (surface-hover) + text-1, press = surface-pressed. Sizes sm/md/lg =
// 32/40/44. Always labelled (Semantics + Tooltip). Focus = 2px ring, 2px
// offset. Background animates 150ms ease-out; no ripples.

import 'package:flutter/material.dart';

import '../mf_theme.dart';

enum MfIconButtonSize { sm, md, lg }

class MfIconButton extends StatefulWidget {
  const MfIconButton({
    super.key,
    required this.label,
    this.size = MfIconButtonSize.md,
    this.onPressed,
    required this.child,
  });

  /// Accessible name — exposed via [Semantics] and shown as a [Tooltip].
  final String label;
  final MfIconButtonSize size;
  final VoidCallback? onPressed;

  /// The glyph (typically an [MfIcon]); inherits the state color via
  /// [DefaultTextStyle].
  final Widget child;

  @override
  State<MfIconButton> createState() => _MfIconButtonState();
}

class _MfIconButtonState extends State<MfIconButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    // Space (WidgetsApp) and Enter (Material) both activate.
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
      widget.onPressed?.call();
      return null;
    }),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
      widget.onPressed?.call();
      return null;
    }),
  };

  double get _side => switch (widget.size) {
        MfIconButtonSize.sm => 32,
        MfIconButtonSize.md => 40,
        MfIconButtonSize.lg => 44,
      };

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final hovered = _enabled && _hovered;
    final pressed = _enabled && _pressed;
    final bg = pressed
        ? mf.surfacePressed
        : hovered
            ? mf.surfaceHover
            : Colors.transparent;
    final fg = hovered || pressed ? mf.text1 : mf.text2;

    Widget button = AnimatedContainer(
      duration: MfMotion.fast,
      curve: MfMotion.curve,
      width: _side,
      height: _side,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MfRadius.md),
      ),
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style: TextStyle(color: fg),
        child: widget.child,
      ),
    );

    button = FocusableActionDetector(
      enabled: _enabled,
      actions: _actions,
      mouseCursor:
          _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: button,
      ),
    );

    // 2px focus ring, 2px outside the edge (design/readme.md "Focus").
    button = Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (_focused)
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MfRadius.md + 4),
                  border: Border.all(color: mf.focusRing, width: 2),
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: Tooltip(message: widget.label, child: button),
    );
  }
}
