// Briefkist design system — button. Source: design/components/actions/Button.jsx
//
// Variants: primary / secondary / destructive / ghost; sizes sm/md/lg
// (32/40/48 tall). Hover = one paper step darker, press = one further step,
// focus = 2px focus ring with 2px offset. Background animates 150ms ease-out;
// no ripples, no scale tricks (design/readme.md "Motion").

import 'package:flutter/material.dart';

import '../mf_theme.dart';

enum MfButtonVariant { primary, secondary, destructive, ghost }

enum MfButtonSize { sm, md, lg }

class MfButton extends StatefulWidget {
  const MfButton({
    super.key,
    this.variant = MfButtonVariant.primary,
    this.size = MfButtonSize.md,
    this.icon,
    this.fullWidth = false,
    this.onPressed,
    required this.label,
  });

  final MfButtonVariant variant;
  final MfButtonSize size;

  /// Optional leading icon (typically an [MfIcon]); inherits the label color
  /// via [DefaultTextStyle].
  final Widget? icon;
  final bool fullWidth;

  /// Null disables the button (45% opacity, no interactions).
  final VoidCallback? onPressed;
  final String label;

  @override
  State<MfButton> createState() => _MfButtonState();
}

class _MfButtonState extends State<MfButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    // Space (WidgetsApp) and Enter (Material) both activate.
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onPressed?.call();
        return null;
      },
    ),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
      onInvoke: (_) {
        widget.onPressed?.call();
        return null;
      },
    ),
  };

  double get _height => switch (widget.size) {
    MfButtonSize.sm => 32,
    MfButtonSize.md => 40,
    MfButtonSize.lg => 48,
  };

  double get _hPadding => switch (widget.size) {
    MfButtonSize.sm => 12,
    MfButtonSize.md => 16,
    MfButtonSize.lg => 22,
  };

  TextStyle get _baseStyle => switch (widget.size) {
    MfButtonSize.sm => MfType.sm,
    MfButtonSize.md => MfType.base,
    MfButtonSize.lg => MfType.md,
  };

  /// Resolved per-state colors, mirroring the .mfBtn--* CSS rules.
  ({Color bg, Color fg, Color border}) _colors(MfColors mf) {
    final hovered = _enabled && _hovered;
    final pressed = _enabled && _pressed;
    switch (widget.variant) {
      case MfButtonVariant.primary:
        return (
          bg: hovered || pressed ? mf.accentHover : mf.accent,
          fg: mf.textOnAccent,
          border: Colors.transparent,
        );
      case MfButtonVariant.secondary:
        return (
          bg: pressed
              ? mf.surfacePressed
              : hovered
              ? mf.surfaceHover
              : mf.surfaceCard,
          fg: mf.text1,
          border: mf.borderStrong,
        );
      case MfButtonVariant.destructive:
        return (
          bg: hovered || pressed ? mf.errTint : Colors.transparent,
          fg: mf.err,
          border: mf.err,
        );
      case MfButtonVariant.ghost:
        return (
          bg: pressed
              ? mf.surfacePressed
              : hovered
              ? mf.surfaceHover
              : Colors.transparent,
          fg: hovered || pressed ? mf.text1 : mf.text2,
          border: Colors.transparent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final c = _colors(mf);
    final textStyle = _baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: c.fg,
    );

    Widget button = AnimatedContainer(
      duration: MfMotion.fast,
      curve: MfMotion.curve,
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: _hPadding),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(MfRadius.md),
        border: Border.all(color: c.border),
      ),
      child: DefaultTextStyle(
        style: textStyle,
        child: Row(
          mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              widget.icon!,
              const SizedBox(width: 8),
            ],
            Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );

    button = FocusableActionDetector(
      enabled: _enabled,
      actions: _actions,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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

    // 2px focus ring, 2px outside the button edge (design/readme.md "Focus").
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

    if (widget.fullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      child: Opacity(opacity: _enabled ? 1.0 : 0.45, child: button),
    );
  }
}
