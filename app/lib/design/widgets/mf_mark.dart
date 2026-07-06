// my-flopy design system — brand mark + wordmark. Source: design/assets/logo.svg
// (glyph path bundled in mf_icons.dart as MfGlyphs.mark).
//
// The mark is a floppy-disk outline whose label area is an envelope flap —
// one continuous geometric shape, works at 16px (design/readme.md
// "Iconography"). The wordmark pairs it with "my-flopy" in Lora.

import 'package:flutter/widgets.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

class MfMark extends StatelessWidget {
  const MfMark({super.key, this.size = 24, this.color});

  final double size;

  /// Defaults to the ink text color (text-1).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return MfIcon(MfGlyphs.mark, size: size, color: color ?? context.mf.text1);
  }
}

class MfWordmark extends StatelessWidget {
  const MfWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const MfMark(size: 24),
        const SizedBox(width: 9),
        Text(
          'my-flopy',
          style: TextStyle(
            fontFamily: MfFonts.serif,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: context.mf.text1,
          ),
        ),
      ],
    );
  }
}
