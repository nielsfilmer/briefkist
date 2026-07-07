// Briefkist design system — app header. Source: design/components/navigation/AppHeader.jsx

import 'package:flutter/material.dart';

import '../mf_theme.dart';
import 'mf_mark.dart';
import 'mf_privacy_mark.dart';

/// 56px app header on the page surface with a 1px bottom hairline:
/// [leading], then the brand wordmark (or a serif [title]), a spacer, the
/// privacy mark for [connection], and trailing [actions]. Gap 14 throughout.
class MfAppHeader extends StatelessWidget {
  const MfAppHeader({
    super.key,
    this.title,
    this.connection,
    this.leading,
    this.actions,
  });

  final String? title;
  final MfPrivacyTone? connection;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final children = <Widget>[
      ?leading,
      // The middle slot fills the remaining width so trailing items sit
      // flush right (the mirror's flex spacer).
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: title == null
              // Not const: the sibling widget's constructor may not be const.
              // ignore: prefer_const_constructors
              ? MfWordmark()
              : Text(
                  title!,
                  style: MfType.serifLg.copyWith(color: mf.text1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
      if (connection != null) MfPrivacyMark(tone: connection!),
      ...?actions,
    ];
    final row = <Widget>[];
    for (final child in children) {
      if (row.isNotEmpty) row.add(const SizedBox(width: 14));
      row.add(child);
    }
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: mf.surfacePage,
        border: Border(bottom: BorderSide(color: mf.border)),
      ),
      child: Row(children: row),
    );
  }
}
