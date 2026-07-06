// my-flopy design system — tab bar. Source: design/components/navigation/TabBar.jsx

import 'package:flutter/material.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

/// One tab of [MfTabBar]; [glyph] is an [MfGlyphs] path string.
class MfTabItem {
  const MfTabItem({required this.id, required this.label, required this.glyph});

  final String id, label;
  final String glyph;
}

const _defaultItems = [
  MfTabItem(id: 'capture', label: 'Capture', glyph: MfGlyphs.camera),
  MfTabItem(id: 'archive', label: 'Archive', glyph: MfGlyphs.archive),
  MfTabItem(id: 'settings', label: 'Settings', glyph: MfGlyphs.gear),
];

/// Bottom tab bar: equal-flex buttons (min 52px + bottom safe area), 22px
/// glyph over a 12px label, 1px top hairline on the page surface. Inactive
/// tabs are muted (one step darker on hover), the active tab is accent +
/// semibold. No ripples.
class MfTabBar extends StatelessWidget {
  const MfTabBar({super.key, this.items, required this.active, this.onSelect});

  final List<MfTabItem>? items;
  final String active;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final list = items ?? _defaultItems;
    return Container(
      decoration: BoxDecoration(
        color: mf.surfacePage,
        border: Border(top: BorderSide(color: mf.border)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Row(
        children: [
          for (final item in list)
            Expanded(
              child: _TabButton(
                item: item,
                active: item.id == active,
                onTap: onSelect == null ? null : () => onSelect!(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({required this.item, required this.active, this.onTap});

  final MfTabItem item;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final color = widget.active ? mf.accent : (_hover ? mf.text2 : mf.text3);
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MfIcon(widget.item.glyph, size: 22, color: color),
                const SizedBox(height: 3),
                Text(
                  widget.item.label,
                  style: MfType.xs.copyWith(
                    color: color,
                    height: 1,
                    fontWeight: widget.active
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
