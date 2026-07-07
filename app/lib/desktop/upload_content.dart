// Briefkist — upload. Source: design/ui_kits/desktop/kit.desktop.jsx

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../app_config.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_icon_button.dart';
import '../design/widgets/mf_page_thumb.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_status_badge.dart';
import '../design/widgets/mf_toast.dart';
import '../uploads_controller.dart';

/// Image types the pipeline accepts today.
const _imageExtensions = ['jpg', 'jpeg', 'png', 'heic', 'webp'];

/// The live drop zone + recent-uploads list, per the kit's UploadContent.
class UploadContent extends StatefulWidget {
  const UploadContent({
    super.key,
    required this.uploads,
    required this.onOpenDoc,
  });

  final UploadsController uploads;
  final void Function(int docId) onOpenDoc;

  @override
  State<UploadContent> createState() => _UploadContentState();
}

class _UploadContentState extends State<UploadContent> {
  /// A drag with files is over the drop zone.
  bool _dragHover = false;

  static bool _isImagePath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return _imageExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  Future<void> _browse() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'images', extensions: _imageExtensions),
      ],
    );
    if (files.isEmpty || !mounted) return;
    await _file([for (final f in files) f.path]);
  }

  /// File one document: ALL [paths] become its pages, in the given order
  /// (kit: "multiple pages become one document").
  Future<void> _file(List<String> paths) async {
    final pages = [
      for (final p in paths)
        if (_isImagePath(p)) p,
    ];
    if (pages.length < paths.length) {
      showMfToast(
        context,
        'Only image files can be filed.',
        tone: MfToastTone.info,
      );
    }
    if (pages.isEmpty) return;
    try {
      await widget.uploads.upload(pages);
      if (!mounted) return;
      showMfToast(
        context,
        '${pages.length} page${pages.length == 1 ? '' : 's'} uploading to '
        'your server.',
      );
    } on Exception {
      // The controller keeps the failed entry (with its honest detail) in
      // the pending list; surface the same copy as a toast.
      if (!mounted) return;
      PendingUpload? failed;
      for (final e in widget.uploads.pending) {
        if (e.failed) {
          failed = e;
          break;
        }
      }
      showMfToast(
        context,
        failed?.failureDetail ?? "The upload didn't go through.",
        tone: MfToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return ListenableBuilder(
      listenable: widget.uploads,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dropZone(mf),
            _sideLabel(mf, 'Recent uploads'),
            if (widget.uploads.offline)
              // Quiet inline warning — the pending list below still matters
              // while the server list can't be refreshed.
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: MfPrivacyMark(tone: MfPrivacyTone.warn),
              ),
            _recentList(mf),
          ],
        ),
      ),
    );
  }

  Widget _dropZone(MfColors mf) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragHover = true),
      onDragExited: (_) => setState(() => _dragHover = false),
      onDragDone: (details) {
        setState(() => _dragHover = false);
        _file([for (final f in details.files) f.path]);
      },
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: _dragHover ? mf.accent : mf.borderStrong,
          radius: MfRadius.xl,
        ),
        child: AnimatedContainer(
          duration: MfMotion.fast,
          curve: MfMotion.curve,
          padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
          decoration: BoxDecoration(
            color: _dragHover ? mf.accentTint : mf.surfaceCard,
            borderRadius: BorderRadius.circular(MfRadius.xl),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: mf.accentTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: MfIcon(MfGlyphs.upload, size: 26, color: mf.accent),
              ),
              const SizedBox(height: 12),
              Text(
                'Drop letter scans here',
                textAlign: TextAlign.center,
                style: MfType.serifLg.copyWith(color: mf.text1),
              ),
              const SizedBox(height: 12),
              // Kit says "Photos or PDFs" — PDF import is a later phase, so
              // the copy promises photos only.
              Text(
                'Photos · multiple pages become one document',
                textAlign: TextAlign.center,
                style: MfType.sm.copyWith(color: mf.text2),
              ),
              const SizedBox(height: 12),
              MfButton(
                variant: MfButtonVariant.secondary,
                label: 'Browse files',
                onPressed: _browse,
              ),
              const SizedBox(height: 12),
              const MfPrivacyMark(label: 'uploads go to your server only'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentList(MfColors mf) {
    final uploads = widget.uploads;
    final client = AppConfigScope.of(context).client;
    final rows = <Widget>[
      for (final entry in uploads.pending)
        _PendingRow(
          entry: entry,
          onDismiss: () => uploads.dismissFailed(entry),
        ),
      for (final doc in uploads.recent)
        _RecentRow(
          doc: doc,
          client: client,
          onOpen: doc.status == 'done' ? () => widget.onOpenDoc(doc.id) : null,
        ),
    ];
    if (rows.isEmpty) {
      return Text(
        'Nothing uploaded yet — drop a scan above.',
        style: MfType.sm.copyWith(color: mf.text3),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 1, color: mf.border),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// Mono-caps section label, per the kit's SideLabel (margin 22/0/8).
  Widget _sideLabel(MfColors mf, String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: MfType.monoCaps.copyWith(color: mf.text3),
    ),
  );
}

/// An upload still in the HTTP phase (or failed there): placeholder thumb,
/// 'Letter', an Uploading…/error badge, and — when failed — the controller's
/// honest detail plus a dismiss control.
class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.entry, required this.onDismiss});

  final PendingUpload entry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      child: Row(
        children: [
          const MfPageThumb(width: 34, height: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.pageCount > 1
                      ? 'Letter · ${entry.pageCount} pages'
                      : 'Letter',
                  style: MfType.base.copyWith(color: mf.text1),
                ),
                if (entry.failed && entry.failureDetail != null)
                  Text(
                    entry.failureDetail!,
                    style: MfType.sm.copyWith(color: mf.err),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          entry.failed
              ? const MfStatusBadge(status: MfStatus.error)
              : const MfStatusBadge(
                  status: MfStatus.processing,
                  label: 'Uploading…',
                ),
          // The kit's 70px time column; failed rows put the dismiss control
          // in it, in-flight rows keep it empty for alignment.
          SizedBox(
            width: 70,
            child: entry.failed
                ? Align(
                    alignment: Alignment.centerRight,
                    child: MfIconButton(
                      label: 'Dismiss',
                      size: MfIconButtonSize.sm,
                      onPressed: onDismiss,
                      child: const MfIcon(MfGlyphs.x, size: 16),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// One server-known document: thumb, title (serif when titled), status badge
/// and relative time. Filed rows open the document.
class _RecentRow extends StatefulWidget {
  const _RecentRow({required this.doc, required this.client, this.onOpen});

  final DocumentSummary doc;
  final FlopyClient? client;
  final VoidCallback? onOpen;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final doc = widget.doc;
    final client = widget.client;
    final done = doc.status == 'done';
    final titled = doc.title != null;

    final badge = switch (doc.status) {
      'queued' => const MfStatusBadge(status: MfStatus.queued),
      'processing' => const MfStatusBadge(
        status: MfStatus.processing,
        label: 'Reading your letter…',
      ),
      'failed' => const MfStatusBadge(
        status: MfStatus.error,
        label: "Couldn't read this letter",
      ),
      _ => MfStatusBadge(
        status: MfStatus.done,
        label: doc.category == null ? 'Filed' : 'Filed · ${doc.category}',
      ),
    };

    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      color: widget.onOpen != null && _hovered
          ? mf.surfaceHover
          : Colors.transparent,
      child: Row(
        children: [
          MfPageThumb(
            width: 34,
            height: 44,
            image: done && client != null
                ? NetworkImage(
                    client.imageUri(doc.id, 1).toString(),
                    headers: client.authHeaders,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              doc.title ?? 'Letter',
              style: titled
                  ? MfType.base.copyWith(
                      fontFamily: MfFonts.serif,
                      fontWeight: FontWeight.w600,
                      color: mf.text1,
                    )
                  : MfType.base.copyWith(color: mf.text1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 14),
          badge,
          const SizedBox(width: 14),
          SizedBox(
            width: 70,
            child: Text(
              relativeTime(doc.createdAt),
              textAlign: TextAlign.right,
              style: MfType.monoXs.copyWith(color: mf.text3),
            ),
          ),
        ],
      ),
    );

    if (widget.onOpen == null) return row;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          child: row,
        ),
      ),
    );
  }
}

/// 1.5px dashed rounded border, matching the kit's CSS `1.5px dashed`.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    // Walk the outline and stroke 5-on / 5-off dashes.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5 < metric.length
            ? distance + 5
            : metric.length;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
