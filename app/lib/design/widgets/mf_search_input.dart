// my-flopy design system — search input. Source: design/components/inputs/SearchInput.jsx

import 'package:flutter/material.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

/// Pill-shaped search field: 44px tall, full radius, leading search glyph.
/// Focus shows the 2px plum ring (border goes transparent, as the mirror does).
class MfSearchInput extends StatelessWidget {
  const MfSearchInput({
    super.key,
    this.controller,
    this.onChanged,
    this.placeholder = 'Search your mail — words or meaning',
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String placeholder;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return _SearchField(
      controller: controller,
      onChanged: onChanged,
      placeholder: placeholder,
      autofocus: autofocus,
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    this.controller,
    this.onChanged,
    required this.placeholder,
    required this.autofocus,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String placeholder;
  final bool autofocus;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return _FocusRing(
      focused: _focused,
      radius: MfRadius.full,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: mf.surfaceCard,
          borderRadius: BorderRadius.circular(MfRadius.full),
          border: Border.all(
            color: _focused ? Colors.transparent : mf.borderStrong,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              // Mirror: padding 0 14px 0 40px (icon sits inside the left gap).
              padding: const EdgeInsets.only(left: 40, right: 14),
              child: Center(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  textInputAction: TextInputAction.search,
                  style: MfType.md.copyWith(color: mf.text1),
                  cursorColor: mf.accent,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: MfType.md.copyWith(color: mf.text3),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: MfIcon(MfGlyphs.search, size: 18, color: mf.text3),
              ),
            ),
          ],
        ),
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
