// Briefkist design system — chip. Source: design/components/display/Chip.jsx
//
// Full-round 26px pill: surface-inset + text-2; interactive chips hover to
// surface-pressed + text-1; selected = accent-tint bg, accent text, 1px
// accent border (the unselected border is transparent so selection never
// shifts layout). Optional trailing remove (x) affordance. No transition in
// the source CSS — state changes are instant.

import 'package:flutter/material.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

class MfChip extends StatefulWidget {
  const MfChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
  });

  final String label;
  final bool selected;

  /// Non-null makes the chip interactive (hover treatment, click cursor,
  /// keyboard-activatable).
  final VoidCallback? onTap;

  /// Non-null shows a trailing 12px x-glyph remove button.
  final VoidCallback? onRemove;

  @override
  State<MfChip> createState() => _MfChipState();
}

class _MfChipState extends State<MfChip> {
  bool _hovered = false;
  bool _focused = false;
  bool _removeHovered = false;

  bool get _interactive => widget.onTap != null;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onTap?.call();
        return null;
      },
    ),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
      onInvoke: (_) {
        widget.onTap?.call();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    // Selected wins over hover. Deliberate divergence from the mirror, where
    // `.mfChip--interactive:hover` out-specifies `.mfChip--selected` so hover
    // repaints a selected chip — logged in docs/design-feedback.md #6.
    final Color bg;
    final Color fg;
    final Color border;
    if (widget.selected) {
      bg = mf.accentTint;
      fg = mf.accent;
      border = mf.accent;
    } else if (_interactive && _hovered) {
      bg = mf.surfacePressed;
      fg = mf.text1;
      border = Colors.transparent;
    } else {
      bg = mf.surfaceInset;
      fg = mf.text2;
      border = Colors.transparent;
    }

    Widget chip = Container(
      height: 26,
      // The remove button carries margin-right:-4px in the source, so the
      // right padding shrinks from 11 to 7 when it is present.
      padding: EdgeInsets.only(
        left: 11,
        right: widget.onRemove != null ? 7 : 11,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MfRadius.full),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.label,
            style: MfType.sm.copyWith(color: fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.onRemove != null) ...[
            const SizedBox(width: 6),
            _removeButton(mf, fg),
          ],
        ],
      ),
    );

    if (_interactive) {
      chip = FocusableActionDetector(
        actions: _actions,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: chip,
        ),
      );

      // 2px focus ring, 2px outside the edge (design/readme.md "Focus").
      chip = Stack(
        clipBehavior: Clip.none,
        children: [
          chip,
          if (_focused)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MfRadius.full),
                    border: Border.all(color: mf.focusRing, width: 2),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Semantics(
      button: _interactive,
      selected: widget.selected,
      child: chip,
    );
  }

  Widget _removeButton(MfColors mf, Color fg) {
    return Semantics(
      button: true,
      label: 'Remove',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _removeHovered = true),
        onExit: (_) => setState(() => _removeHovered = false),
        child: GestureDetector(
          // An inner tap recognizer wins the gesture arena, so removing
          // never also triggers the chip's own onTap.
          onTap: widget.onRemove,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _removeHovered ? mf.surfacePressed : Colors.transparent,
              borderRadius: BorderRadius.circular(MfRadius.full),
            ),
            child: MfIcon(MfGlyphs.x, size: 12, color: fg, strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
