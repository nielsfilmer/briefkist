// my-flopy — desktop upload (drop-zone preview; the live flow lands in the
// next PR). Source: design/ui_kits/desktop/kit.desktop.jsx

import 'package:flutter/material.dart';

import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_privacy_mark.dart';

/// Static preview of the kit's drop zone. Nothing here pretends to work:
/// the zone is dimmed and captioned, the browse button is disabled, and the
/// empty state below says when upload arrives.
class UploadContent extends StatelessWidget {
  const UploadContent({super.key});

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 60% opacity + caption: the zone must read as a preview, not as
          // a dead control that looks live.
          Opacity(
            opacity: 0.6,
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: mf.borderStrong,
                radius: MfRadius.xl,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 52,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: mf.surfaceCard,
                  borderRadius: BorderRadius.circular(MfRadius.xl),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: mf.accentTint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: MfIcon(
                        MfGlyphs.upload,
                        size: 26,
                        color: mf.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Drop letter scans here',
                      textAlign: TextAlign.center,
                      style: MfType.serifLg.copyWith(color: mf.text1),
                    ),
                    const SizedBox(height: 12),
                    // Kit says "Photos or PDFs" — PDF import is a later
                    // phase, so the copy promises photos only.
                    Text(
                      'Photos · multiple pages become one document',
                      textAlign: TextAlign.center,
                      style: MfType.sm.copyWith(color: mf.text2),
                    ),
                    const SizedBox(height: 12),
                    const MfButton(
                      variant: MfButtonVariant.secondary,
                      label: 'Browse files',
                      onPressed: null, // enabled when upload lands
                    ),
                    const SizedBox(height: 12),
                    const MfPrivacyMark(
                      label: 'uploads go to your server only',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'preview — not active yet',
              style: MfType.monoXs.copyWith(color: mf.text3),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: MfEmptyState(title: 'Upload arrives in the next update.'),
          ),
        ],
      ),
    );
  }
}

/// 1.5px dashed rounded border, matching the kit's CSS `1.5px dashed`.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    // Walk the outline and stroke 5-on / 5-off dashes.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5 < metric.length
            ? distance + 5
            : metric.length;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
