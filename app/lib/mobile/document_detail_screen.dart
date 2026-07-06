// my-flopy — document detail screen. Source: design/ui_kits/mobile/kit.mobile.jsx

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_app_header.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_chip.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_icon_button.dart';
import '../design/widgets/mf_meta_row.dart';
import '../design/widgets/mf_page_thumb.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_sheet.dart';
import '../design/widgets/mf_toast.dart';

enum _LoadError { unreachable, server }

/// A single archived document: page thumbs, title + summary, editable
/// metadata card, keywords — pushed as its own route with a back header.
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.docId,
    required this.client,
  });

  final int docId;
  final FlopyClient client;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  DocumentDetail? _detail;
  _LoadError? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_detail != null || _error != null) {
      setState(() {
        _detail = null;
        _error = null;
      });
    }
    try {
      final detail = await widget.client.getDocument(widget.docId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on ServerUnreachable {
      if (!mounted) return;
      setState(() => _error = _LoadError.unreachable);
    } on ApiError {
      if (!mounted) return;
      setState(() => _error = _LoadError.server);
    }
  }

  /// Apply a correction; the PATCH response is the updated document, so the
  /// UI re-syncs from it directly.
  Future<void> _save(Map<String, dynamic> patch) async {
    try {
      final updated = await widget.client.correctDocument(widget.docId, patch);
      if (!mounted) return;
      setState(() => _detail = updated);
      showMfToast(context, 'Saved.');
    } on ApiError {
      if (!mounted) return;
      // The server 422s malformed dates (deterministic validation, plan.md
      // §6.4) — tell the user the format instead of a generic failure.
      showMfToast(
        context,
        patch.containsKey('document_date')
            ? 'Not a valid date — use YYYY-MM-DD.'
            : "The server couldn't save that change.",
        tone: MfToastTone.error,
      );
    } on ServerUnreachable {
      if (!mounted) return;
      showMfToast(
        context,
        "Can't reach your home server — nothing was saved.",
        tone: MfToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // No privacy mark on detail (kit: connection={null}).
            MfAppHeader(
              title: 'Document',
              leading: MfIconButton(
                label: 'Back',
                size: MfIconButtonSize.lg,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const MfIcon(MfGlyphs.back, size: 20, strokeWidth: 2),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) return _errorState();
    final detail = _detail;
    if (detail == null) return const _DetailSkeleton();
    return _content(detail);
  }

  Widget _errorState() {
    final mf = context.mf;
    final unreachable = _error == _LoadError.unreachable;
    return Center(
      child: SingleChildScrollView(
        child: MfEmptyState(
          icon: unreachable
              ? MfIcon(
                  MfGlyphs.wifiOff,
                  size: 44,
                  strokeWidth: 1.5,
                  color: mf.warn,
                )
              : MfIcon(MfGlyphs.alert, size: 44, color: mf.err),
          title: unreachable
              ? "Can't reach your home server"
              : "Can't load this document",
          body: unreachable
              ? 'Your archive lives only on your own server — connect to '
                    'your home network or VPN, then try again.'
              : 'The server returned an error. Try again in a moment.',
          action: MfButton(
            variant: MfButtonVariant.secondary,
            label: 'Try again',
            onPressed: _load,
          ),
        ),
      ),
    );
  }

  Widget _content(DocumentDetail d) {
    final mf = context.mf;
    final s = d.summary;
    final pageNos = d.pages.isNotEmpty
        ? [for (final p in d.pages) p.pageNo]
        : [for (var i = 1; i <= s.pageCount; i++) i];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pageNos.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final n = pageNos[index];
              return MfPageThumb(
                width: 84,
                height: 110,
                pageNumber: n,
                semanticLabel: 'page $n scan',
                // Page images can 404 until processing finishes; the thumb
                // shows its own placeholder when no image is passed.
                image: s.status == 'done'
                    ? NetworkImage(
                        widget.client.imageUri(widget.docId, n).toString(),
                        headers: widget.client.authHeaders,
                      )
                    : null,
                onTap: () => _openViewer(n),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.title ?? 'Untitled document',
          style: MfType.serifXl.copyWith(color: mf.text1),
        ),
        if (s.summary != null) ...[
          const SizedBox(height: 10),
          Text(s.summary!, style: MfType.base.copyWith(color: mf.text2)),
        ],
        const SizedBox(height: 18),
        _metaCard(d, mf),
        if (s.keywords.isNotEmpty) ...[
          const _SectionLabel('Keywords'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final k in s.keywords) MfChip(label: k)],
          ),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Center(child: MfPrivacyMark()),
        ),
      ],
    );
  }

  Widget _metaCard(DocumentDetail d, MfColors mf) {
    final s = d.summary;
    final name = s.correspondent;
    final place = s.correspondentPlace;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 14),
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
      ),
      child: Column(
        children: [
          // The kit merges 'name · place' into one row; since place is a
          // separate, separately-edited server field (its own row below),
          // the merged display duplicated it — QA (PR #36) → name only here.
          MfMetaRow(
            label: 'correspondent',
            value: name,
            corrected: d.isVerified('correspondent'),
            onSave: (v) => _save({'correspondent': v}),
          ),
          MfMetaRow(
            label: 'place',
            value: place,
            corrected: d.isVerified('correspondent_place'),
            onSave: (v) => _save({'correspondent_place': v}),
          ),
          // recipient (in the kit) is omitted: the DocumentDetail model
          // surfaces the field, but the server neither extracts nor accepts
          // a recipient yet — a permanently 'not detected' row would read as
          // an extraction failure.
          MfMetaRow(
            label: 'document date',
            value: s.documentDate,
            mono: true,
            corrected: d.isVerified('document_date'),
            onSave: (v) => _save({'document_date': v}),
          ),
          MfMetaRow(
            label: 'category',
            editable: false,
            corrected: d.isVerified('category'),
            child: MfChip(
              label: s.category ?? 'not detected',
              onTap: _pickCategory,
            ),
          ),
          MfMetaRow(
            label: 'reference',
            value: s.reference,
            mono: true,
            corrected: d.isVerified('reference'),
            onSave: (v) => _save({'reference': v}),
          ),
          MfMetaRow(
            label: 'language',
            value: s.language,
            corrected: d.isVerified('language'),
            onSave: (v) => _save({'language': v}),
          ),
          MfMetaRow(
            label: 'subject',
            value: d.subject,
            corrected: d.isVerified('subject'),
            onSave: (v) => _save({'subject': v}),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  void _pickCategory() {
    final current = _detail?.summary.category;
    showMfSheet<void>(
      context,
      title: 'Category',
      builder: (sheetContext) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cat in kCategories)
            MfChip(
              label: cat,
              selected: cat == current,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _save({'category': cat});
              },
            ),
        ],
      ),
    );
  }

  void _openViewer(int pageNo) {
    // Full-screen viewer over a scrim, per the kit's ImageViewer overlay —
    // a transparent route so the detail stays visible underneath.
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: MfMotion.base,
        reverseTransitionDuration: MfMotion.base,
        pageBuilder: (context, animation, secondaryAnimation) => _ImageViewer(
          docId: widget.docId,
          pageNo: pageNo,
          client: widget.client,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: MfMotion.curve,
              ),
              child: child,
            ),
      ),
    );
  }
}

/// Full-screen page viewer: scrim, cleaned/original segmented pill, close
/// button, the page in a rounded 3/4 box, mono caption.
class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.docId,
    required this.pageNo,
    required this.client,
  });

  final int docId;
  final int pageNo;
  final FlopyClient client;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  String _kind = 'cleaned';

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: mf.scrim,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _segmented(mf),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MfRadius.full),
                      child: ColoredBox(
                        color: mf.surfaceCard,
                        child: MfIconButton(
                          label: 'Close viewer',
                          size: MfIconButtonSize.lg,
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const MfIcon(
                            MfGlyphs.x,
                            size: 18,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 290),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: mf.surfaceCard,
                            borderRadius: BorderRadius.circular(MfRadius.md),
                            boxShadow: MfShadows.overlay(
                              Theme.of(context).brightness,
                            ),
                          ),
                          child: Image.network(
                            widget.client
                                .imageUri(
                                  widget.docId,
                                  widget.pageNo,
                                  kind: _kind,
                                )
                                .toString(),
                            headers: widget.client.authHeaders,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Text(
                                    'scan not available yet',
                                    style: MfType.monoXs.copyWith(
                                      color: mf.text3,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Text(
                  'page ${widget.pageNo} · $_kind scan',
                  style: MfType.monoXs.copyWith(color: mf.paper1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmented(MfColors mf) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final kind in const ['cleaned', 'original'])
            _segmentButton(mf, kind),
        ],
      ),
    );
  }

  Widget _segmentButton(MfColors mf, String kind) {
    final selected = _kind == kind;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _kind = kind),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? mf.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(MfRadius.full),
          ),
          child: Text(
            kind,
            style: MfType.sm.copyWith(
              fontWeight: FontWeight.w500,
              color: selected ? mf.textOnAccent : mf.text2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered loading placeholder with the brand's slow opacity pulse.
class _DetailSkeleton extends StatefulWidget {
  const _DetailSkeleton();

  @override
  State<_DetailSkeleton> createState() => _DetailSkeletonState();
}

class _DetailSkeletonState extends State<_DetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: MfMotion.pulse ~/ 2,
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.55,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    Widget box(double width, double height, double radius) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: mf.surfaceInset,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return Center(
      child: FadeTransition(
        opacity: _opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            box(84, 110, MfRadius.md),
            const SizedBox(height: 14),
            box(200, 14, 4),
            const SizedBox(height: 8),
            box(140, 11, 4),
          ],
        ),
      ),
    );
  }
}

/// Mono caps section label (the kit's SectionLabel: margin 20/0/8).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: MfType.monoCaps.copyWith(color: context.mf.text3),
      ),
    );
  }
}
