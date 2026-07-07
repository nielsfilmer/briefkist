// Briefkist design system — toast. Source: design/components/feedback/Toast.jsx

import 'dart:async';

import 'package:flutter/material.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

enum MfToastTone { info, ok, error }

/// The toast surface: overlay background, 1px border, radius 10, raised
/// shadow, leading 16px tone glyph, optional trailing text action.
class MfToast extends StatelessWidget {
  const MfToast({
    super.key,
    this.tone = MfToastTone.info,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final MfToastTone tone;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final (glyph, glyphColor) = switch (tone) {
      MfToastTone.ok => (MfGlyphs.check, mf.ok),
      MfToastTone.error => (MfGlyphs.alert, mf.err),
      MfToastTone.info => (MfGlyphs.info, mf.text2),
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: mf.surfaceOverlay,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
        boxShadow: MfShadows.raised(Theme.of(context).brightness),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MfIcon(glyph, size: 16, color: glyphColor, strokeWidth: 2),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message, style: MfType.sm.copyWith(color: mf.text1)),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 10),
            _ToastAction(label: actionLabel!, onTap: onAction),
          ],
        ],
      ),
    );
  }
}

/// Show a transient toast bottom-centered in the root overlay: slides in 8px
/// + fades over 200ms ease-out, auto-dismisses after [duration].
///
/// [bottomOffset] positions it above the bottom edge — 24 on desktop, 76 to
/// clear the mobile tab bar.
void showMfToast(
  BuildContext context,
  String message, {
  MfToastTone tone = MfToastTone.ok,
  Duration duration = const Duration(milliseconds: 2600),
  double bottomOffset = 24,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _MfToastHost(
      bottomOffset: bottomOffset,
      duration: duration,
      onDismissed: () => entry.remove(),
      child: MfToast(tone: tone, message: message),
    ),
  );
  overlay.insert(entry);
}

class _MfToastHost extends StatefulWidget {
  const _MfToastHost({
    required this.bottomOffset,
    required this.duration,
    required this.onDismissed,
    required this.child,
  });

  final double bottomOffset;
  final Duration duration;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<_MfToastHost> createState() => _MfToastHostState();
}

class _MfToastHostState extends State<_MfToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MfMotion.base,
  );
  late final CurvedAnimation _t = CurvedAnimation(
    parent: _controller,
    curve: MfMotion.curve,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.bottomOffset,
      child: Center(
        child: AnimatedBuilder(
          animation: _t,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              liveRegion: true,
              container: true,
              child: widget.child,
            ),
          ),
          builder: (context, child) => Opacity(
            opacity: _t.value,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - _t.value)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastAction extends StatefulWidget {
  const _ToastAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_ToastAction> createState() => _ToastActionState();
}

class _ToastActionState extends State<_ToastAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            color: _hover ? mf.surfaceHover : null,
            borderRadius: BorderRadius.circular(MfRadius.sm),
          ),
          child: Text(
            widget.label,
            style: MfType.sm.copyWith(
              color: mf.textLink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
