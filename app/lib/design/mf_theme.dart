// my-flopy design system — theme layer.
// Hand-translated from design/tokens/*.css (the Claude Design mirror);
// colors come from the generated tokens.g.dart. Keep 1:1 with the mirror —
// deviations belong in docs/design-feedback.md.

import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

/// Resolve the active palette. Light is default; dark mirrors
/// `[data-theme="dark"]`.
extension MfContext on BuildContext {
  MfColors get mf =>
      Theme.of(this).brightness == Brightness.dark ? mfDark : mfLight;
}

/// Spacing scale — design/tokens/spacing.css `--space-*`.
abstract final class MfSpace {
  static const s1 = 2.0;
  static const s2 = 4.0;
  static const s3 = 6.0;
  static const s4 = 8.0;
  static const s5 = 12.0;
  static const s6 = 16.0;
  static const s7 = 20.0;
  static const s8 = 24.0;
  static const s9 = 32.0;
  static const s10 = 40.0;
  static const s11 = 48.0;
  static const s12 = 64.0;

  /// Minimum touch target (`--hit-target` — a size token in spacing.css).
  static const hitTarget = 44.0;
}

/// Radius scale — design/tokens/spacing.css `--radius-*`.
abstract final class MfRadius {
  static const sm = 4.0; // small controls
  static const md = 6.0; // buttons, inputs
  static const lg = 10.0; // cards, menus
  static const xl = 16.0; // sheets, dialogs, image viewer
  static const full = 999.0; // chips, pills
}

/// Motion — design/readme.md "Motion": quiet, 150–200ms ease-out, no bounces.
abstract final class MfMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 240);
  static const pulse = Duration(milliseconds: 1600);
  static const curve = Curves.easeOut;
}

/// Font families — design/tokens/typography.css. Bundled in assets/fonts/.
abstract final class MfFonts {
  static const serif = 'Lora';
  static const sans = 'Source Sans 3';
  static const mono = 'Source Code Pro';
}

/// Type scale — design/tokens/typography.css `--text-* / --leading-*`.
/// Sizes are px == logical pt; height = leading / size.
abstract final class MfType {
  static const _f = MfFonts.sans;

  static const xs = TextStyle(fontFamily: _f, fontSize: 12, height: 16 / 12);
  static const sm = TextStyle(fontFamily: _f, fontSize: 13, height: 18 / 13);
  static const base = TextStyle(fontFamily: _f, fontSize: 15, height: 22 / 15);
  static const md = TextStyle(fontFamily: _f, fontSize: 17, height: 24 / 17);
  static const lg = TextStyle(fontFamily: _f, fontSize: 20, height: 28 / 20);

  /// Serif sizes — document titles and brand moments (Lora).
  static const serifMd = TextStyle(
    fontFamily: MfFonts.serif,
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const serifLg = TextStyle(
    fontFamily: MfFonts.serif,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const serifXl = TextStyle(
    fontFamily: MfFonts.serif,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const serif2xl = TextStyle(
    fontFamily: MfFonts.serif,
    fontSize: 30,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  /// Mono — references, dates-in-metadata, technical trust moments.
  static const mono = TextStyle(
    fontFamily: MfFonts.mono,
    fontSize: 13,
    height: 18 / 13,
  );
  static const monoXs = TextStyle(
    fontFamily: MfFonts.mono,
    fontSize: 12,
    height: 16 / 12,
  );

  /// Mono all-caps label — `--tracking-caps: 0.08em` at 12px.
  static const monoCaps = TextStyle(
    fontFamily: MfFonts.mono,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.96,
  );
}

/// Elevation — design/tokens/elevation.css. Flat by default; warm-tinted soft
/// shadows on raised (menus/toasts) and overlay (dialog/sheet) surfaces only.
abstract final class MfShadows {
  static List<BoxShadow> raised(Brightness b) => b == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
          BoxShadow(
            color: Color(0x4D000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0F272229),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
          BoxShadow(
            color: Color(0x14272229),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ];

  static List<BoxShadow> overlay(Brightness b) => b == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x59000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Color(0x73000000),
            offset: Offset(0, 16),
            blurRadius: 40,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1A272229),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Color(0x29272229),
            offset: Offset(0, 16),
            blurRadius: 40,
          ),
        ];
}

/// Build the app ThemeData for one brightness. Material widgets are restyled
/// to the paper/ink/plum system; most UI uses the Mf* widgets directly.
ThemeData mfThemeData(Brightness brightness) {
  final c = brightness == Brightness.dark ? mfDark : mfLight;
  final base = MfType.base.copyWith(color: c.text1);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: MfFonts.sans,
    scaffoldBackgroundColor: c.surfacePage,
    canvasColor: c.surfacePage,
    dividerColor: c.border,
    splashFactory: NoSplash.splashFactory, // press = one paper step, no ripples
    highlightColor: c.surfacePressed,
    hoverColor: c.surfaceHover,
    focusColor: c.plumTint,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.textOnAccent,
      secondary: c.accentTint,
      onSecondary: c.accent,
      error: c.err,
      onError: c.surfaceCard,
      surface: c.surfaceCard,
      onSurface: c.text1,
      outline: c.border,
      outlineVariant: c.borderStrong,
      surfaceContainerHighest: c.surfaceInset,
      onSurfaceVariant: c.text2,
      shadow: const Color(0x14272229),
      scrim: c.scrim,
      inverseSurface: c.ink1,
      onInverseSurface: c.paper1,
      inversePrimary: c.plumTint,
      primaryContainer: c.accentTint,
      onPrimaryContainer: c.accent,
      secondaryContainer: c.surfaceInset,
      onSecondaryContainer: c.text2,
      tertiary: c.ok,
      onTertiary: c.okTint,
      tertiaryContainer: c.okTint,
      onTertiaryContainer: c.ok,
      errorContainer: c.errTint,
      onErrorContainer: c.err,
    ),
    textTheme: TextTheme(
      bodyMedium: base,
      bodySmall: MfType.sm.copyWith(color: c.text2),
      bodyLarge: MfType.md.copyWith(color: c.text1),
      titleLarge: MfType.serifXl.copyWith(color: c.text1),
      titleMedium: MfType.serifLg.copyWith(color: c.text1),
      titleSmall: MfType.serifMd.copyWith(color: c.text1),
      labelSmall: MfType.monoCaps.copyWith(color: c.text3),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.plumTint,
      selectionHandleColor: c.accent,
    ),
  );
}
