// Briefkist design system — dialog. Source: design/components/feedback/Dialog.jsx

import 'package:flutter/material.dart';

import '../mf_theme.dart';

/// Show a modal dialog over the scrim: fades in 150ms ease-out, dismissible
/// by tapping the barrier.
Future<T?> showMfDialog<T>(
  BuildContext context, {
  String? title,
  required Widget body,
  List<Widget>? actions,
}) {
  final mf = context.mf;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: mf.scrim,
    transitionDuration: MfMotion.fast,
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: MfMotion.curve),
          child: child,
        ),
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: Center(
        child: Padding(
          // Mirror: the scrim has 24px padding around the panel.
          padding: const EdgeInsets.all(24),
          child: MfDialogSurface(title: title, body: body, actions: actions),
        ),
      ),
    ),
  );
}

/// The dialog panel itself: overlay surface, radius 16, overlay shadow,
/// max-width 420, 24px padding.
class MfDialogSurface extends StatelessWidget {
  const MfDialogSurface({
    super.key,
    this.title,
    required this.body,
    this.actions,
  });

  final String? title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: mf.surfaceOverlay,
          borderRadius: BorderRadius.circular(MfRadius.xl),
          boxShadow: MfShadows.overlay(Theme.of(context).brightness),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(title!, style: MfType.serifLg.copyWith(color: mf.text1)),
                const SizedBox(height: 8),
              ],
              DefaultTextStyle(
                style: MfType.base.copyWith(color: mf.text2),
                child: body,
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      actions![i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
