// my-flopy design system — document card. Source: design/components/display/DocumentCard.jsx

import 'package:flutter/material.dart';

import '../mf_theme.dart';
import 'mf_chip.dart';
import 'mf_page_thumb.dart';
import 'mf_status_badge.dart';

/// Card layout density: a list row or a grid tile.
enum MfCardDensity { list, grid }

/// An archive document card: page thumb + serif title + correspondent/date
/// sub-row + status badge (while processing) or category chip footer.
class MfDocumentCard extends StatefulWidget {
  const MfDocumentCard({
    super.key,
    this.density = MfCardDensity.list,
    this.title,
    this.correspondent,
    this.date,
    this.category,
    this.status = MfStatus.done,
    this.pages = 1,
    this.image,
    this.onOpen,
  });

  final MfCardDensity density;
  final String? title;
  final String? correspondent;
  final String? date;
  final String? category;
  final MfStatus status;
  final int pages;
  final ImageProvider? image;
  final VoidCallback? onOpen;

  @override
  State<MfDocumentCard> createState() => _MfDocumentCardState();
}

class _MfDocumentCardState extends State<MfDocumentCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final bg = _pressed
        ? mf.surfacePressed
        : _hovered
            ? mf.surfaceHover
            : mf.surfaceCard;

    final card = AnimatedContainer(
      duration: MfMotion.fast,
      curve: MfMotion.curve,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
      ),
      child: widget.density == MfCardDensity.grid ? _grid(mf) : _list(mf),
    );

    return Semantics(
      button: true,
      child: FocusableActionDetector(
        enabled: widget.onOpen != null,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (h) => setState(() => _hovered = h),
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onOpen?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onOpen,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          // Focus = 2px focusRing ring at 2px offset, painted outside the
          // card bounds so layout never shifts.
          child: CustomPaint(
            foregroundPainter: _focused
                ? _FocusRingPainter(color: mf.focusRing, radius: MfRadius.lg)
                : null,
            child: card,
          ),
        ),
      ),
    );
  }

  int? get _pageBadge => widget.pages > 1 ? widget.pages : null;

  Widget _list(MfColors mf) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Keep the thumb at its fixed 56x74 while the body stretches.
            Align(
              alignment: Alignment.topCenter,
              widthFactor: 1,
              child: MfPageThumb(
                image: widget.image,
                width: 56,
                height: 74,
                pageNumber: _pageBadge,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _body(mf, listDensity: true)),
          ],
        ),
      );

  Widget _grid(MfColors mf) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MfPageThumb(
            image: widget.image,
            width: double.infinity,
            height: 120,
            pageNumber: _pageBadge,
          ),
          const SizedBox(height: 10),
          _body(mf, listDensity: false),
        ],
      );

  Widget _body(MfColors mf, {required bool listDensity}) {
    final processing = widget.status != MfStatus.done;
    final title = widget.title ??
        (processing ? 'Reading your letter…' : 'Untitled document');

    final subChildren = <Widget>[
      if (widget.correspondent != null)
        Text(
          widget.correspondent!,
          style: MfType.sm.copyWith(color: mf.text2),
        ),
      if (widget.date != null)
        Text(widget.date!, style: MfType.monoXs.copyWith(color: mf.text3)),
    ];

    Widget? foot;
    if (processing) {
      foot = MfStatusBadge(status: widget.status);
    } else if (widget.category != null) {
      foot = MfChip(label: widget.category!);
    }

    return Column(
      mainAxisSize: listDensity ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MfType.serifMd.copyWith(color: mf.text1),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subChildren.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: subChildren,
          ),
        ],
        const SizedBox(height: 4),
        if (listDensity) const Spacer(),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: foot == null
              ? const SizedBox.shrink()
              : Row(children: [foot]),
        ),
      ],
    );
  }
}

/// Paints the plum focus ring 2px outside the card (2px offset, 2px stroke).
class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(3),
      Radius.circular(radius + 3),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
