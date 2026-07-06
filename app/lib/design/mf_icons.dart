// my-flopy design system — icon glyphs.
// The exact stroke glyphs used by the design kits (design/ui_kits/*.jsx and
// design/components/*.jsx): 24x24 viewBox, 1.75 stroke, round caps/joins,
// currentColor. Bundled as SVG path data per plan.md decision v0.5 #16 —
// no icon CDN. Multi-path glyphs are joined with spaces (SVG path syntax
// allows it; `M` restarts a subpath).

import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

/// Path data per glyph, verbatim from the design mirror.
abstract final class MfGlyphs {
  static const camera =
      'M4 8h3l2-3h6l2 3h3v12H4Z M12 9.5 A3.5 3.5 0 1 1 11.99 9.5 Z';
  static const back = 'm15 18-6-6 6-6';
  static const filter = 'M4 6h16M7 12h10M10 18h4';
  static const plus = 'M12 5v14M5 12h14';
  static const x = 'M18 6 6 18M6 6l12 12';
  static const wifiOff =
      'M2 8.8A15 15 0 0 1 12 5c3.8 0 7.3 1.4 10 3.8 M5.5 12.5A10 10 0 0 1 12 10c2.5 0 4.8.9 6.5 2.5 M9 16.2a5 5 0 0 1 6 0 M12 20h.01 m-9-17 18 18';
  static const qr =
      'M3 3h7v7H3Z M14 3h7v7h-7Z M3 14h7v7H3Z M14 14h3v3h-3zM20 14h1M14 20h1M20 20h1';
  static const search = 'M11 4 A7 7 0 1 1 10.99 4 Z m9 16-3.8-3.8';
  static const grid =
      'M4 4h7v7H4Z M13 4h7v7h-7Z M4 13h7v7H4Z M13 13h7v7h-7Z';
  static const rows = 'M4 6h16M4 12h16M4 18h16';
  static const upload = 'M12 16V4m0 0 5 5m-5-5L7 9 M4 20h16';
  static const gear =
      'M12 9 A3 3 0 1 1 11.99 9 Z M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M19 5l-2 2M7 17l-2 2';
  static const archive = 'M3 7h18v4H3Z M5 11v9h14v-9 M10 15h4';
  static const home = 'M3 10.5 12 3l9 7.5 M5 9v11h14V9';
  static const check = 'M20 6 9 17l-5-5';
  static const pencil = 'M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z';
  static const chevronDown = 'm6 9 6 6 6-6';
  static const alert = 'M12 3 A9 9 0 1 1 11.99 3 Z M12 8v5m0 3.5v0';
  static const info = 'M12 3 A9 9 0 1 1 11.99 3 Z M12 11v5m0-8.5v0';

  /// The brand mark — floppy-disk outline whose label area is an envelope
  /// flap (design/assets/logo.svg).
  static const mark =
      'M4 4h12.5L20 7.5V20H4Z M8 4v2.6l4 3 4-3V4 M8 20v-5.5h8V20';
}

/// Circle-as-path helper glyphs above use arc commands; painting is a plain
/// stroke of the parsed path scaled from the 24x24 design grid.
class MfIcon extends StatelessWidget {
  const MfIcon(
    this.pathData, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.75,
    this.semanticLabel,
  });

  final String pathData;
  final double size;
  final Color? color;

  /// Stroke width on the 24x24 grid (scales with [size]).
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    return Semantics(
      label: semanticLabel,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MfIconPainter(pathData, c, strokeWidth),
      ),
    );
  }
}

/// The brand's empty-state motif: dashed postmark circle + FILED/LOCAL text +
/// wavy cancellation lines (design/assets/postmark.svg, 120x56 viewBox).
class MfPostmark extends StatelessWidget {
  const MfPostmark({super.key, this.width = 150, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    return CustomPaint(
      size: Size(width, width * 56 / 120),
      painter: _MfPostmarkPainter(c),
    );
  }
}

class _MfPostmarkPainter extends CustomPainter {
  _MfPostmarkPainter(this.color);

  final Color color;

  static const _waves =
      'M56 20c6-4 10 4 16 0s10 4 16 0s10 4 16 0 M56 28c6-4 10 4 16 0s10 4 16 0s10 4 16 0 M56 36c6-4 10 4 16 0s10 4 16 0s10 4 16 0';

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120;
    canvas.scale(scale);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    // dashed circle (r=20 at 28,28; stroke-dasharray 4 5)
    final circle = Path()
      ..addOval(Rect.fromCircle(center: const Offset(28, 28), radius: 20));
    canvas.drawPath(
      dashPath(circle, dashArray: CircularIntervalList<double>([4, 5])),
      paint,
    );
    canvas.drawPath(parseSvgPathData(_waves), paint);
    // FILED / LOCAL mono caption inside the circle
    for (final (text, dy) in [('FILED', 25.0), ('LOCAL', 35.0)]) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Source Code Pro',
            fontSize: 7,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(28 - tp.width / 2, dy - tp.height + 2));
    }
  }

  @override
  bool shouldRepaint(_MfPostmarkPainter old) => old.color != color;
}

class _MfIconPainter extends CustomPainter {
  _MfIconPainter(this.pathData, this.color, this.strokeWidth);

  final String pathData;
  final Color color;
  final double strokeWidth;

  static final _cache = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cache.putIfAbsent(pathData, () => parseSvgPathData(pathData));
    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_MfIconPainter old) =>
      old.pathData != pathData ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
