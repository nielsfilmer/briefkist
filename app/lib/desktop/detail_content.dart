// my-flopy — desktop document detail (side-by-side image + metadata).
// Source: design/ui_kits/desktop/kit.desktop.jsx

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_chip.dart';
import '../design/widgets/mf_dialog.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_focus_ring.dart';
import '../design/widgets/mf_meta_row.dart';
import '../design/widgets/mf_page_thumb.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_toast.dart';

/// Two-panel document view: page images (left, inset surface) and the
/// title/summary/metadata card (right). Fetches on init; corrections PATCH
/// through [FlopyClient.correctDocument] and re-render from the response.
class DetailContent extends StatefulWidget {
  const DetailContent({
    super.key,
    required this.docId,
    required this.client,
    required this.onBack,
  });

  final int docId;
  final FlopyClient client;
  final VoidCallback onBack;

  @override
  State<DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<DetailContent> {
  DocumentDetail? _detail;
  Object? _error;
  bool _loading = true;

  /// Index into the page list (0-based).
  int _pageIndex = 0;

  /// 'cleaned' | 'original' — doubles as the image `kind` query value.
  String _mode = 'cleaned';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.client.getDocument(widget.docId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        final maxIndex = _pageCount(detail) - 1;
        if (_pageIndex > maxIndex) _pageIndex = maxIndex < 0 ? 0 : maxIndex;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  static int _pageCount(DocumentDetail detail) =>
      detail.pages.isEmpty ? detail.summary.pageCount : detail.pages.length;

  /// Server page number for page list index [i] (1-based fallback when the
  /// detail carries no page rows yet).
  int _pageNo(int i) {
    final detail = _detail!;
    return detail.pages.isEmpty ? i + 1 : detail.pages[i].pageNo;
  }

  Future<void> _patch(String field, dynamic value) async {
    try {
      final updated = await widget.client.correctDocument(widget.docId, {
        field: value,
      });
      if (!mounted) return;
      setState(() => _detail = updated);
      showMfToast(context, 'Saved.');
    } on ApiError {
      if (!mounted) return;
      showMfToast(
        context,
        field == 'document_date'
            ? 'Not a valid date — use YYYY-MM-DD.'
            : "Couldn't save that value.",
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

  /// Text-field corrections: an emptied field clears the value.
  void _saveText(String field, String draft) {
    final t = draft.trim();
    _patch(field, t.isEmpty ? null : t);
  }

  Future<void> _chooseCategory() async {
    final current = _detail!.summary.category;
    final picked = await showMfDialog<String>(
      context,
      title: 'Category',
      // Builder so the pop uses the dialog route's own context, not the
      // screen's.
      body: Builder(
        builder: (dialogContext) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kCategories)
              MfChip(
                label: c,
                selected: c == current,
                onTap: () => Navigator.of(dialogContext).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) await _patch('category', picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _SkeletonDetail(onBack: widget.onBack);
    if (_error != null || _detail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: _BackButton(onBack: widget.onBack),
          ),
          Expanded(
            child: Center(
              child: MfEmptyState(
                title: "Couldn't load this document",
                body: _error is ServerUnreachable
                    ? 'Your archive lives only on your own server. Check '
                          'the VPN connection and try again.'
                    : 'Something went wrong on your server. Try again.',
                action: MfButton(
                  variant: MfButtonVariant.secondary,
                  label: 'Try again',
                  onPressed: _fetch,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kit: flex 46% with min-width 340. Flutter flexes can't carry a
        // minimum, so the split relies on desktop window sizes.
        Expanded(flex: 46, child: _imagePanel(context)),
        Expanded(flex: 54, child: _metadataPanel(context)),
      ],
    );
  }

  // ── left: page images ────────────────────────────────────────────
  Widget _imagePanel(BuildContext context) {
    final mf = context.mf;
    final detail = _detail!;
    final pageCount = _pageCount(detail);
    final pageNo = _pageNo(_pageIndex);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: mf.surfaceInset,
        border: Border(right: BorderSide(color: mf.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ModePill(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              Text(
                'page ${_pageIndex + 1} of $pageCount · $_mode',
                style: MfType.monoXs.copyWith(color: mf.text3),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.78,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MfRadius.md),
                      boxShadow: MfShadows.raised(Theme.of(context).brightness),
                    ),
                    child: Image.network(
                      widget.client
                          .imageUri(widget.docId, pageNo, kind: _mode)
                          .toString(),
                      headers: widget.client.authHeaders,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stack) => AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Container(
                          color: mf.surfaceCard,
                          alignment: Alignment.center,
                          child: Text(
                            'page scan unavailable',
                            style: MfType.monoXs.copyWith(color: mf.text3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Wrap, not Row: a long document must not overflow the panel.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < pageCount; i++)
                // Selected thumb: 2px accent outline — the focus-ring
                // helper draws exactly that (focusRing == accent).
                MfFocusRing(
                  focused: i == _pageIndex,
                  radius: MfRadius.md,
                  child: MfPageThumb(
                    width: 44,
                    height: 58,
                    pageNumber: i + 1,
                    semanticLabel: 'page ${i + 1}',
                    image: NetworkImage(
                      widget.client
                          .imageUri(widget.docId, _pageNo(i))
                          .toString(),
                      headers: widget.client.authHeaders,
                    ),
                    onTap: () => setState(() => _pageIndex = i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── right: metadata ──────────────────────────────────────────────
  Widget _metadataPanel(BuildContext context) {
    final mf = context.mf;
    final detail = _detail!;
    final s = detail.summary;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onBack: widget.onBack),
          const SizedBox(height: 10),
          Text(
            s.title ?? 'Untitled document',
            style: MfType.serif2xl.copyWith(color: mf.text1),
          ),
          if (s.summary != null) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                s.summary!,
                style: MfType.base.copyWith(color: mf.text2),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
            decoration: BoxDecoration(
              color: mf.surfaceCard,
              border: Border.all(color: mf.border),
              borderRadius: BorderRadius.circular(MfRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MfMetaRow(
                  label: 'correspondent',
                  value: s.correspondent,
                  corrected: detail.isVerified('correspondent'),
                  onSave: (v) => _saveText('correspondent', v),
                ),
                MfMetaRow(
                  label: 'place',
                  value: s.correspondentPlace,
                  corrected: detail.isVerified('correspondent_place'),
                  onSave: (v) => _saveText('correspondent_place', v),
                ),
                // Shown as the raw ISO string (not formatDate) so the value
                // round-trips through the edit field: the server accepts
                // corrections as YYYY-MM-DD only.
                MfMetaRow(
                  label: 'document date',
                  value: s.documentDate,
                  mono: true,
                  corrected: detail.isVerified('document_date'),
                  onSave: (v) => _saveText('document_date', v),
                ),
                MfMetaRow(
                  label: 'category',
                  editable: false,
                  corrected: detail.isVerified('category'),
                  child: MfChip(
                    label: s.category ?? 'other',
                    onTap: _chooseCategory,
                  ),
                ),
                MfMetaRow(
                  label: 'reference',
                  value: s.reference,
                  mono: true,
                  corrected: detail.isVerified('reference'),
                  onSave: (v) => _saveText('reference', v),
                ),
                MfMetaRow(
                  label: 'language',
                  value: s.language,
                  corrected: detail.isVerified('language'),
                  onSave: (v) => _saveText('language', v),
                ),
                // No recipient row: the field is not in the server model
                // yet (DocumentDetail.recipient is always null server-side).
                MfMetaRow(
                  label: 'subject',
                  value: detail.subject,
                  corrected: detail.isVerified('subject'),
                  onSave: (v) => _saveText('subject', v),
                  showDivider: false,
                ),
              ],
            ),
          ),
          if (s.keywords.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 8),
              child: Text(
                'KEYWORDS',
                style: MfType.monoCaps.copyWith(color: mf.text3),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final k in s.keywords) MfChip(label: k)],
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 22),
            child: MfPrivacyMark(),
          ),
        ],
      ),
    );
  }
}

/// Ghost '← Archive' back button (sm, text-2, hover one paper step).
class _BackButton extends StatefulWidget {
  const _BackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final fg = _hovered ? mf.text1 : mf.text2;
    return Semantics(
      button: true,
      label: 'Back to archive',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBack,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: _hovered ? mf.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(MfRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MfIcon(MfGlyphs.back, size: 16, color: fg, strokeWidth: 2),
                const SizedBox(width: 6),
                Text('Archive', style: MfType.sm.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cleaned/original segmented pill (full-round, card surface, 3px inner
/// padding; the active segment is solid accent).
class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
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
          for (final m in const ['cleaned', 'original'])
            _ModeSegment(
              label: m,
              active: m == mode,
              onTap: () => onChanged(m),
            ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatefulWidget {
  const _ModeSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ModeSegment> createState() => _ModeSegmentState();
}

class _ModeSegmentState extends State<_ModeSegment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Semantics(
      button: true,
      selected: widget.active,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: MfMotion.fast,
            curve: MfMotion.curve,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
            decoration: BoxDecoration(
              color: widget.active ? mf.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(MfRadius.full),
            ),
            child: Text(
              widget.label,
              style: MfType.sm.copyWith(
                fontWeight: FontWeight.w500,
                color: widget.active
                    ? mf.textOnAccent
                    : _hovered
                    ? mf.text1
                    : mf.text2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton mirroring the two-panel layout, on the brand's slow
/// pulse.
class _SkeletonDetail extends StatefulWidget {
  const _SkeletonDetail({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_SkeletonDetail> createState() => _SkeletonDetailState();
}

class _SkeletonDetailState extends State<_SkeletonDetail>
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

  Widget _block(MfColors mf, {double? width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return FadeTransition(
      opacity: _opacity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 46,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: mf.surfaceInset,
                border: Border(right: BorderSide(color: mf.border)),
              ),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.78,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _block(mf, height: double.infinity),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 54,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 18, 26, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(onBack: widget.onBack),
                  const SizedBox(height: 14),
                  _block(mf, width: 320, height: 34),
                  const SizedBox(height: 14),
                  _block(mf, width: 460, height: 60),
                  const SizedBox(height: 20),
                  _block(mf, width: double.infinity, height: 280),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
