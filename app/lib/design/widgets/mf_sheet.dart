// my-flopy design system — sheet. Source: design/components/feedback/Sheet.jsx

import 'package:flutter/material.dart';

import '../mf_theme.dart';

/// Show a bottom sheet over the scrim: slides up 24px + fades in over 240ms
/// ease-out (the mirror's `mfSheetUp` keyframes), dismissible by tapping the
/// barrier.
Future<T?> showMfSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  final mf = context.mf;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: mf.scrim,
    transitionDuration: MfMotion.sheet,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final t = CurvedAnimation(parent: animation, curve: MfMotion.curve);
      return AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 24 * (1 - t.value)),
          child: Opacity(opacity: 0.6 + 0.4 * t.value, child: child),
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: MfSheetSurface(title: title, child: Builder(builder: builder)),
      ),
    ),
  );
}

/// The sheet panel itself: overlay surface, 16px top radius, overlay shadow,
/// grab handle, optional serif title.
class MfSheetSurface extends StatelessWidget {
  const MfSheetSurface({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      width: double.infinity,
      // Mirror: padding 8px 20px 24px, plus the device safe area.
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + safeBottom),
      decoration: BoxDecoration(
        color: mf.surfaceOverlay,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(MfRadius.xl)),
        boxShadow: MfShadows.overlay(Theme.of(context).brightness),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: MfType.base.copyWith(color: mf.text1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 6, bottom: 14),
                  decoration: BoxDecoration(
                    color: mf.borderStrong,
                    borderRadius: BorderRadius.circular(MfRadius.full),
                  ),
                ),
              ),
              if (title != null) ...[
                Text(title!, style: MfType.serifLg.copyWith(color: mf.text1)),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
