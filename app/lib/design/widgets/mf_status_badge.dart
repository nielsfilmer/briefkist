// Briefkist design system — status badge. Source: design/components/display/StatusBadge.jsx
//
// Full-round 24px pill with a 7px dot of the current color. Tint background +
// tone text per status; the processing dot pulses opacity 1 → 0.3 → 1 over
// 1.6s ease-in-out, repeating — the brand's slow pulse, never a spinner
// (design/readme.md "Motion").

import 'package:flutter/material.dart';

import '../mf_theme.dart';

enum MfStatus { queued, processing, done, error, offline }

class MfStatusBadge extends StatefulWidget {
  const MfStatusBadge({super.key, required this.status, this.label});

  final MfStatus status;

  /// Overrides the default label for [status].
  final String? label;

  static const Map<MfStatus, String> defaultLabels = {
    MfStatus.queued: 'Queued',
    MfStatus.processing: 'Processing…',
    MfStatus.done: 'Filed',
    MfStatus.error: 'Needs attention',
    MfStatus.offline: 'Waiting for network',
  };

  @override
  State<MfStatusBadge> createState() => _MfStatusBadgeState();
}

class _MfStatusBadgeState extends State<MfStatusBadge>
    with SingleTickerProviderStateMixin {
  // Half the 1.6s cycle each way; repeat(reverse: true) closes the loop.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: MfMotion.pulse ~/ 2,
  );
  late final Animation<double> _dotOpacity = Tween<double>(
    begin: 1,
    end: 0.3,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse);

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MfStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _syncPulse();
  }

  void _syncPulse() {
    if (widget.status == MfStatus.processing) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0; // dot fully opaque when idle
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final (bg, fg) = switch (widget.status) {
      MfStatus.queued => (mf.surfaceInset, mf.text2),
      MfStatus.processing => (mf.processingTint, mf.processing),
      MfStatus.done => (mf.okTint, mf.ok),
      MfStatus.error => (mf.errTint, mf.err),
      MfStatus.offline => (mf.warnTint, mf.warn),
    };
    final label = widget.label ?? MfStatusBadge.defaultLabels[widget.status]!;

    Widget dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
    );
    if (widget.status == MfStatus.processing) {
      dot = FadeTransition(opacity: _dotOpacity, child: dot);
    }

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MfRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(child: dot),
          const SizedBox(width: 7),
          Text(
            label,
            style: MfType.sm.copyWith(fontWeight: FontWeight.w500, color: fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
