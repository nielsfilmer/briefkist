// Briefkist design system — page thumbnail. Source: design/components/display/PageThumb.jsx

import 'package:flutter/material.dart';

import '../mf_theme.dart';

/// A small page-scan thumbnail: 1px hairline frame, radius md, optional page
/// number badge; a hatched "page scan" placeholder when no image exists yet.
class MfPageThumb extends StatelessWidget {
  const MfPageThumb({
    super.key,
    this.image,
    this.pageNumber,
    this.width = 64,
    this.height = 84,
    this.onTap,
    this.semanticLabel = 'page scan',
  });

  final ImageProvider? image;
  final int? pageNumber;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => _ThumbFrame(spec: this);
}

class _ThumbFrame extends StatefulWidget {
  const _ThumbFrame({required this.spec});

  final MfPageThumb spec;

  @override
  State<_ThumbFrame> createState() => _ThumbFrameState();
}

class _ThumbFrameState extends State<_ThumbFrame> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final s = widget.spec;
    final tappable = s.onTap != null;

    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (s.image != null)
          Image(image: s.image!, fit: BoxFit.cover, excludeFromSemantics: true)
        else ...[
          // 45deg-hatched placeholder: surfaceCard base, 1px surfaceInset
          // lines with a 7px perpendicular period (JSX:
          // repeating-linear-gradient(-45deg, card 0 6px, inset 6px 7px)).
          CustomPaint(
            painter: _HatchPainter(base: mf.surfaceCard, line: mf.surfaceInset),
          ),
          // Below ~64px the pill label wraps mid-word ("pag e sca") — the
          // hatch alone reads as "placeholder" at row-thumb sizes (QA #39).
          if (s.width >= 64)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: mf.surfaceCard,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'page scan',
                  style: TextStyle(
                    fontFamily: MfFonts.mono,
                    fontSize: 10,
                    letterSpacing: 0.6, // 0.06em at 10px
                    color: mf.text3,
                  ),
                ),
              ),
            ),
        ],
        if (s.pageNumber != null)
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
              decoration: BoxDecoration(
                color: mf.scrim,
                borderRadius: BorderRadius.circular(MfRadius.sm),
              ),
              child: Text(
                '${s.pageNumber}',
                style: TextStyle(
                  fontFamily: MfFonts.mono,
                  fontSize: 10,
                  color: mf.plumContrast,
                ),
              ),
            ),
          ),
      ],
    );

    final frame = AnimatedContainer(
      duration: MfMotion.fast,
      curve: MfMotion.curve,
      width: s.width,
      height: s.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        borderRadius: BorderRadius.circular(MfRadius.md),
        border: Border.all(
          color: tappable && _hovered ? mf.borderStrong : mf.border,
        ),
      ),
      child: content,
    );

    if (!tappable) {
      return Semantics(
        label: s.semanticLabel,
        image: s.image != null,
        child: frame,
      );
    }
    return Semantics(
      button: true,
      label: 'Open ${s.semanticLabel}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(onTap: s.onTap, child: frame),
      ),
    );
  }
}

/// Diagonal-stripe placeholder background (bottom-left to top-right lines).
class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.base, required this.line});

  final Color base;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    // 7px period perpendicular to the stripes -> 7 * sqrt(2) along the x-axis.
    const step = 9.8994949366;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.line != line;
}
