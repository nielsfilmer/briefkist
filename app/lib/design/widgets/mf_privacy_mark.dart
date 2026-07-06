// my-flopy design system — privacy mark. Source: design/components/display/PrivacyMark.jsx
//
// The quiet "home" reassurance token shown wherever data moves: a 13px house
// glyph + a mono 12px caption (0.04em tracking = 0.48 at 12px). Informational,
// never a badge shouting (design/readme.md "Privacy mark").

import 'package:flutter/widgets.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

enum MfPrivacyTone { neutral, ok, warn }

class MfPrivacyMark extends StatelessWidget {
  const MfPrivacyMark({super.key, this.tone = MfPrivacyTone.neutral, this.label});

  final MfPrivacyTone tone;

  /// Overrides the default caption for [tone].
  final String? label;

  static const Map<MfPrivacyTone, String> defaultLabels = {
    MfPrivacyTone.neutral: 'on your server',
    MfPrivacyTone.ok: 'connected · home',
    MfPrivacyTone.warn: 'away from home network',
  };

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final color = switch (tone) {
      MfPrivacyTone.neutral => mf.text3,
      MfPrivacyTone.ok => mf.ok,
      MfPrivacyTone.warn => mf.warn,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MfIcon(MfGlyphs.home, size: 13, color: color),
        const SizedBox(width: 7),
        Text(
          label ?? defaultLabels[tone]!,
          style: MfType.monoXs.copyWith(letterSpacing: 0.48, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
