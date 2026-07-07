// Briefkist design system — empty state. Source: design/components/display/EmptyState.jsx

import 'package:flutter/material.dart';

import '../mf_icons.dart';
import '../mf_theme.dart';

/// Centered empty-state block: postmark motif (or a custom [icon]) + serif
/// title + optional body copy and action.
class MfEmptyState extends StatelessWidget {
  const MfEmptyState({
    super.key,
    required this.title,
    this.body,
    this.action,
    this.icon,
  });

  final String title;
  final String? body;
  final Widget? action;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Opacity(
              opacity: 0.8,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: mf.text3),
                child: icon ?? MfPostmark(width: 150, color: mf.text3),
              ),
            ),
          ),
          const SizedBox(height: 6), // column gap
          Text(
            title,
            textAlign: TextAlign.center,
            style: MfType.serifLg.copyWith(color: mf.text1),
          ),
          if (body != null) ...[
            const SizedBox(height: 6), // column gap
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: MfType.base.copyWith(color: mf.text2),
              ),
            ),
          ],
          if (action != null)
            // column gap (6) + the action's own margin-top (14)
            Padding(padding: const EdgeInsets.only(top: 20), child: action!),
        ],
      ),
    );
  }
}
