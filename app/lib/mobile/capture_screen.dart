// my-flopy — capture screen. Source: design/ui_kits/mobile/kit.mobile.jsx

import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_drawing/path_drawing.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../app_config.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_dialog.dart';
import '../design/widgets/mf_icon_button.dart';
import '../design/widgets/mf_page_thumb.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_status_badge.dart';
import '../design/widgets/mf_toast.dart';
import '../uploads_controller.dart';

/// Toasts sit above the mobile tab bar (mf_toast.dart guidance).
const _kToastOffset = 76.0;

/// The capture tab: hero card (camera CTA), the pending-pages tray for the
/// letter being photographed, and the recent-uploads list fed by
/// [UploadsController].
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.uploads,
    required this.onOpenDoc,
  });

  final UploadsController uploads;
  final void Function(int docId) onOpenDoc;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  /// Local file paths of the pages photographed for the current letter,
  /// in page order, not yet uploaded.
  final List<String> _pendingPages = [];

  bool _capturing = false; // a scanner/picker sheet is up
  bool _uploading = false;

  // ── capture ────────────────────────────────────────────────

  Future<void> _addPages() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final paths = await _acquirePages();
      if (!mounted || paths.isEmpty) return;
      setState(() => _pendingPages.addAll(paths));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// The iOS document scanner (edge detection, multi-page) is the first
  /// choice. Its `null` return specifically means USER CANCEL
  /// (documentCameraViewControllerDidCancel in the plugin) — that must stay
  /// a no-op, not open the photo library (review #39 blocking 2). Only a
  /// thrown error (no camera — the simulator, unsupported platform,
  /// permission refused) falls back to the system photo picker, so capture
  /// keeps working everywhere, just without edge detection. (Cancelling the
  /// picker returns an empty list and is a no-op too.)
  Future<List<String>> _acquirePages() async {
    try {
      final scanned = await CunningDocumentScanner.getPictures();
      return scanned ?? const []; // null = user cancelled the scanner
    } on Exception {
      // Scanner unavailable → picker below.
    }
    try {
      final picked = await ImagePicker().pickMultiImage();
      return [for (final f in picked) f.path];
    } on Exception {
      if (mounted) {
        showMfToast(
          context,
          "Couldn't open the camera or photo library on this device.",
          tone: MfToastTone.error,
          bottomOffset: _kToastOffset,
        );
      }
      return const [];
    }
  }

  // ── pending tray ───────────────────────────────────────────

  Future<void> _confirmRemove(int index) async {
    final remove = await showMfDialog<bool>(
      context,
      title: 'Remove this page?',
      body: const Text(
        "This page hasn't been uploaded yet — removing it only "
        'changes this letter.',
      ),
      actions: [
        MfButton(
          variant: MfButtonVariant.ghost,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        MfButton(
          variant: MfButtonVariant.destructive,
          label: 'Remove',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (remove == true && mounted && index < _pendingPages.length) {
      setState(() => _pendingPages.removeAt(index));
    }
  }

  Future<void> _upload() async {
    if (_uploading || _pendingPages.isEmpty) return;
    final pages = List<String>.of(_pendingPages);
    setState(() => _uploading = true);
    try {
      await widget.uploads.upload(pages);
      if (mounted) setState(_pendingPages.clear);
    } catch (_) {
      // The controller already classified the failure (honest failureDetail
      // on the pending entry) — every failure type gets the same toast
      // (review #39 round-2 nit 3: Error subtypes were silent).
      _toastUploadFailure();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// The controller kept the failed entry (with its honest failureDetail) in
  /// `pending` — surface that same message as a toast; the tray keeps the
  /// pages so the user can retry.
  void _toastUploadFailure() {
    if (!mounted) return;
    String? detail;
    for (final u in widget.uploads.pending) {
      if (u.failed) {
        detail = u.failureDetail;
        break;
      }
    }
    showMfToast(
      context,
      detail ?? 'The upload failed.',
      tone: MfToastTone.error,
      bottomOffset: _kToastOffset,
    );
  }

  // ── build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return ListenableBuilder(
      listenable: widget.uploads,
      builder: (context, _) => RefreshIndicator(
        color: mf.accent,
        backgroundColor: mf.surfaceCard,
        onRefresh: widget.uploads.refresh,
        child: ListView(
          // Always scrollable so pull-to-refresh works on a short page.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _heroCard(mf),
            if (_pendingPages.isNotEmpty) ...[
              const _SectionLabel('Pending pages · this letter'),
              _pendingTray(mf),
            ],
            const _SectionLabel('Recent uploads'),
            _recentCard(context, mf),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(MfColors mf) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: _cardBox(mf),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: mf.accentTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: MfIcon(MfGlyphs.camera, size: 30, color: mf.accent),
          ),
          const SizedBox(height: 14),
          Text(
            'Photograph a letter',
            textAlign: TextAlign.center,
            style: MfType.serifLg.copyWith(color: mf.text1),
          ),
          const SizedBox(height: 14),
          MfButton(
            size: MfButtonSize.lg,
            fullWidth: true,
            icon: const MfIcon(MfGlyphs.camera, size: 18),
            label: _pendingPages.isEmpty
                ? 'Open the camera'
                : 'Add another page',
            onPressed: _capturing ? null : _addPages,
          ),
          const SizedBox(height: 14),
          const MfPrivacyMark(label: 'uploads go to your server only'),
        ],
      ),
    );
  }

  Widget _pendingTray(MfColors mf) {
    final n = _pendingPages.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBox(mf),
      child: Row(
        children: [
          // The kit's open row of thumbs; scrolls once a letter has more
          // pages than fit (deviation: the kit mock never overflows).
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < n; i++) ...[
                    MfPageThumb(
                      width: 52,
                      height: 68,
                      pageNumber: i + 1,
                      image: FileImage(File(_pendingPages[i])),
                      semanticLabel: 'pending page ${i + 1} — tap to remove',
                      onTap: () => _confirmRemove(i),
                    ),
                    const SizedBox(width: 10),
                  ],
                  _addTile(mf),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          MfButton(
            label: 'Upload $n page${n == 1 ? '' : 's'}',
            onPressed: _uploading ? null : _upload,
          ),
        ],
      ),
    );
  }

  /// The 52x68 dashed "add" tile at the end of the tray.
  Widget _addTile(MfColors mf) {
    return Semantics(
      button: true,
      enabled: !_capturing,
      label: 'Add page',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _capturing ? null : _addPages,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: mf.borderStrong),
          child: SizedBox(
            width: 52,
            height: 68,
            child: Center(
              child: MfIcon(MfGlyphs.plus, size: 20, color: mf.text3),
            ),
          ),
        ),
      ),
    );
  }

  // ── recent uploads ─────────────────────────────────────────

  Widget _recentCard(BuildContext context, MfColors mf) {
    final client = AppConfigScope.of(context).client;
    final uploads = widget.uploads;
    final rows = <Widget>[
      for (final u in uploads.pending) _pendingRow(mf, u),
      for (final d in uploads.recent) _docRow(mf, client, d),
    ];
    if (rows.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            uploads.offline
                ? "Can't reach your home server — pull to refresh once "
                      "you're back on your network."
                : 'Letters you photograph show up here.',
            style: MfType.sm.copyWith(color: mf.text2),
          ),
        ),
      );
    }
    return Container(
      decoration: _cardBox(mf),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            if (i == 0)
              rows[i]
            else
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: mf.border)),
                ),
                child: rows[i],
              ),
        ],
      ),
    );
  }

  /// An upload still in its HTTP phase (or failed there) — no server id yet.
  Widget _pendingRow(MfColors mf, PendingUpload u) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          const MfPageThumb(width: 40, height: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.pageCount > 1 ? 'Letter · ${u.pageCount} pages' : 'Letter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MfType.base.copyWith(color: mf.text1),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: MfStatusBadge(
                        status: u.failed ? MfStatus.error : MfStatus.processing,
                        label: u.failed
                            ? (u.failureDetail ?? 'The upload failed.')
                            : 'Uploading…',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (u.failed) ...[
            const SizedBox(width: 8),
            MfIconButton(
              label: 'Dismiss failed upload',
              size: MfIconButtonSize.sm,
              onPressed: () => widget.uploads.dismissFailed(u),
              child: const MfIcon(MfGlyphs.x, size: 16),
            ),
          ] else ...[
            const SizedBox(width: 12),
            Text('just now', style: MfType.monoXs.copyWith(color: mf.text3)),
          ],
        ],
      ),
    );
  }

  Widget _docRow(MfColors mf, FlopyClient? client, DocumentSummary d) {
    final done = d.status == 'done';
    final (status, label) = switch (d.status) {
      'queued' => (MfStatus.queued, null),
      'processing' => (MfStatus.processing, 'Reading your letter…'),
      'failed' => (MfStatus.error, "Couldn't read this letter"),
      _ => (
        MfStatus.done,
        d.category == null ? 'Filed' : 'Filed · ${d.category}',
      ),
    };
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          MfPageThumb(
            width: 40,
            height: 52,
            // Thumbnails can 404 while a document is still processing —
            // only request one once the server reports it done.
            image: (client != null && done)
                ? NetworkImage(
                    client.imageUri(d.id, 1).toString(),
                    headers: client.authHeaders,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.title ?? 'Letter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Kit: titled rows switch to the serif at weight 600.
                  style: d.title == null
                      ? MfType.base.copyWith(color: mf.text1)
                      : MfType.base.copyWith(
                          color: mf.text1,
                          fontFamily: MfFonts.serif,
                          fontWeight: FontWeight.w600,
                        ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: MfStatusBadge(status: status, label: label),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            relativeTime(d.createdAt),
            style: MfType.monoXs.copyWith(color: mf.text3),
          ),
        ],
      ),
    );
    if (!done) return row;
    return Semantics(
      button: true,
      label: 'Open ${d.title ?? 'letter'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onOpenDoc(d.id),
        child: row,
      ),
    );
  }

  BoxDecoration _cardBox(MfColors mf) => BoxDecoration(
    color: mf.surfaceCard,
    border: Border.all(color: mf.border),
    borderRadius: BorderRadius.circular(MfRadius.lg),
  );
}

/// Mono caps section label (the kit's SectionLabel: margin 20/0/8).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;
  static const double topMargin = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: MfType.monoCaps.copyWith(color: context.mf.text3),
      ),
    );
  }
}

/// The kit's 1.5px dashed border-strong outline, radius md (Flutter has no
/// native dashed borders).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75); // stroke stays inside
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(MfRadius.md)),
      );
    canvas.drawPath(
      dashPath(path, dashArray: CircularIntervalList<double>([4, 4])),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
