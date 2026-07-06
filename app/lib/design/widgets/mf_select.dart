// my-flopy design system — select. Source: design/components/inputs/Select.jsx

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';
import 'mf_focus_ring.dart';

/// Labelled select control: 40px tall, radius 6, 1px strong border, card
/// surface, trailing 14px chevron. Opens a raised menu (card surface, radius
/// 10, 1px border, raised shadow); hover = one paper step, selected = accent.
class MfSelect extends StatelessWidget {
  const MfSelect({
    super.key,
    this.label,
    required this.options,
    this.value,
    this.onChanged,
    this.placeholder,
  });

  final List<String> options;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? label, placeholder;

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
        _SelectControl(
          options: options,
          value: value,
          onChanged: onChanged,
          placeholder: placeholder,
        ),
      ],
    );
  }
}

class _SelectControl extends StatefulWidget {
  const _SelectControl({
    required this.options,
    this.value,
    this.onChanged,
    this.placeholder,
  });

  final List<String> options;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? placeholder;

  @override
  State<_SelectControl> createState() => _SelectControlState();
}

class _SelectControlState extends State<_SelectControl> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _link = LayerLink();
  OverlayEntry? _menu;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    if (!_focusNode.hasFocus) {
      _menu?.remove();
      _menu = null;
    }
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(_SelectControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _menu?.markNeedsBuild();
  }

  @override
  void dispose() {
    _menu?.remove();
    _menu = null;
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    _focusNode.requestFocus();
    if (_menu == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  void _openMenu() {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final size = box.size;
    _menu = OverlayEntry(
      builder: (context) => _buildMenu(context, size.width, size.height),
    );
    overlay.insert(_menu!);
    setState(() {});
  }

  void _closeMenu() {
    _menu?.remove();
    _menu = null;
    if (mounted) setState(() {});
  }

  void _select(String? option) {
    widget.onChanged?.call(option);
    _closeMenu();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_menu != null) {
        _closeMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _toggle();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMenu(BuildContext context, double width, double height) {
    final mf = context.mf;
    final brightness = Theme.of(context).brightness;
    return Stack(
      children: [
        // Tap anywhere outside dismisses.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeMenu,
          ),
        ),
        Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: Offset(0, height + 4),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: mf.surfaceCard,
                  borderRadius: BorderRadius.circular(MfRadius.lg),
                  border: Border.all(color: mf.border),
                  boxShadow: MfShadows.raised(brightness),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MfRadius.lg - 1),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.placeholder != null)
                          _MenuItem(
                            label: widget.placeholder!,
                            muted: true,
                            selected: false,
                            onTap: () => _select(null),
                          ),
                        for (final option in widget.options)
                          _MenuItem(
                            label: option,
                            selected: option == widget.value,
                            onTap: () => _select(option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final hasValue = widget.value != null;
    return CompositedTransformTarget(
      link: _link,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: Semantics(
          button: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: MfFocusRing(
                focused: _focused,
                radius: MfRadius.md,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: mf.surfaceCard,
                    borderRadius: BorderRadius.circular(MfRadius.md),
                    border: Border.all(
                      color: _focused ? Colors.transparent : mf.borderStrong,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        // Mirror: padding 0 34px 0 12px.
                        padding: const EdgeInsets.only(left: 12, right: 34),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.value ?? widget.placeholder ?? '',
                            style: MfType.base.copyWith(
                              color: hasValue ? mf.text1 : mf.text3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: MfIcon(
                            MfGlyphs.chevronDown,
                            size: 14,
                            color: mf.text3,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    required this.label,
    required this.selected,
    this.muted = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool muted;
  final VoidCallback onTap;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final color = widget.muted
        ? mf.text3
        : (widget.selected ? mf.accent : mf.text1);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: _hover ? mf.surfaceHover : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.label,
            style: MfType.base.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
