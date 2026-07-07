// Briefkist design system — shared keyboard-focus ring.
// 2px focusRing ring at 1px offset (the inputs' `outline-offset: 1px` in the
// component sources; the ring sits 3px outside the child bounds: 1px offset
// + 2px stroke). Drawn in a non-clipping Stack so it never shifts layout.

import 'package:flutter/widgets.dart';

import '../mf_theme.dart';

class MfFocusRing extends StatelessWidget {
  const MfFocusRing({
    super.key,
    required this.focused,
    required this.radius,
    required this.child,
  });

  final bool focused;

  /// Corner radius of the child; the ring adds its offset on top.
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (focused)
          Positioned(
            left: -3,
            top: -3,
            right: -3,
            bottom: -3,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 3),
                  border: Border.all(color: context.mf.focusRing, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
