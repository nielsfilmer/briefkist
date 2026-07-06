// my-flopy — archive browse/search screen. Source: design/ui_kits/mobile/kit.mobile.jsx

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../app_config.dart';
import '../archive_controller.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_chip.dart';
import '../design/widgets/mf_document_card.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_icon_button.dart';
import '../design/widgets/mf_search_input.dart';
import '../design/widgets/mf_sheet.dart';
import '../design/widgets/mf_status_badge.dart';
import '../design/widgets/mf_text_field.dart';

/// The archive tab: search + category chips over a card list, with the
/// content states of the design (loading / offline / error / empty /
/// no matches).
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onGoCapture,
  });

  final ArchiveController controller;
  final void Function(DocumentSummary) onOpen;
  final VoidCallback onGoCapture;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.query,
  );

  @override
  void didUpdateWidget(ArchiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _search.text = widget.controller.query;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Server status vocabulary (queued|processing|done|failed) → badge status.
  MfStatus _status(String status) => switch (status) {
    'queued' => MfStatus.queued,
    'processing' => MfStatus.processing,
    'failed' => MfStatus.error,
    _ => MfStatus.done,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        // The kit hides the search chrome on the empty, offline and error
        // states.
        final hideChrome =
            c.state == ArchiveState.empty ||
            c.state == ArchiveState.offline ||
            c.state == ArchiveState.error;
        return Column(
          children: [
            if (!hideChrome) ...[_searchRow(), _categoryRow()],
            Expanded(child: _body(context)),
          ],
        );
      },
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: MfSearchInput(
              controller: _search,
              onChanged: widget.controller.setQuery,
            ),
          ),
          const SizedBox(width: 8),
          MfIconButton(
            label: 'Filters',
            size: MfIconButtonSize.lg,
            onPressed: _openFilters,
            child: const MfIcon(MfGlyphs.filter, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow() {
    final c = widget.controller;
    // Kit: gap 8, padding 12px 2px 10px inside the 16px-padded block (whose
    // own 4px bottom is folded into the 14 here).
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Row(
          children: [
            MfChip(
              label: 'All',
              selected: c.category == null,
              onTap: () => c.setCategory(null),
            ),
            for (final cat in kCategories) ...[
              const SizedBox(width: 8),
              MfChip(
                label: cat,
                selected: c.category == cat,
                onTap: () => c.setCategory(c.category == cat ? null : cat),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = widget.controller;
    const pad = EdgeInsets.fromLTRB(16, 4, 16, 24);
    switch (c.state) {
      case ArchiveState.loading:
        return ListView(
          padding: pad,
          children: const [
            _SkeletonCard(),
            SizedBox(height: 10),
            _SkeletonCard(),
            SizedBox(height: 10),
            _SkeletonCard(),
          ],
        );
      case ArchiveState.offline:
        return ListView(
          padding: pad,
          children: [
            MfEmptyState(
              icon: MfIcon(
                MfGlyphs.wifiOff,
                size: 44,
                strokeWidth: 1.5,
                color: context.mf.warn,
              ),
              title: "Can't reach your home server",
              body:
                  "You're away from your home network. Your archive lives "
                  'only on your own server — connect to the VPN to browse it.',
              action: MfButton(
                variant: MfButtonVariant.secondary,
                label: 'Try again',
                onPressed: c.refresh,
              ),
            ),
          ],
        );
      case ArchiveState.error:
        return ListView(
          padding: pad,
          children: [
            MfEmptyState(
              icon: MfIcon(MfGlyphs.alert, size: 44, color: context.mf.err),
              title: 'Your server said no',
              body: c.errorMessage,
              action: MfButton(
                variant: MfButtonVariant.secondary,
                label: 'Try again',
                onPressed: c.refresh,
              ),
            ),
          ],
        );
      case ArchiveState.empty:
        return ListView(
          padding: pad,
          children: [
            MfEmptyState(
              title: 'Nothing filed yet',
              body: 'Your first letter is one photo away.',
              action: MfButton(
                size: MfButtonSize.lg,
                icon: const MfIcon(MfGlyphs.camera, size: 18),
                label: 'Photograph a letter',
                onPressed: widget.onGoCapture,
              ),
            ),
          ],
        );
      case ArchiveState.noMatches:
        return ListView(
          padding: pad,
          children: [
            MfEmptyState(
              title: 'No matches',
              body: c.query.isEmpty
                  ? 'Nothing in your archive matches these filters.'
                  : 'Nothing in your archive matches “${c.query}”. Search '
                        'looks at words and meaning — try describing the '
                        'letter instead.',
            ),
          ],
        );
      case ArchiveState.populated:
        final client = AppConfigScope.of(context).client;
        return ListView.separated(
          padding: pad,
          itemCount: c.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final d = c.docs[index];
            return MfDocumentCard(
              title: d.title,
              correspondent: d.correspondent,
              date: d.documentDate == null ? null : formatDate(d.documentDate),
              category: d.category,
              status: _status(d.status),
              pages: d.pageCount,
              // Thumbnails can 404 while a document is still processing —
              // only request one once the server reports it done; the thumb
              // shows its own placeholder otherwise.
              image: (client != null && d.status == 'done')
                  ? NetworkImage(
                      client.imageUri(d.id, 1).toString(),
                      headers: client.authHeaders,
                    )
                  : null,
              onOpen: () => widget.onOpen(d),
            );
          },
        );
    }
  }

  void _openFilters() {
    showMfSheet<void>(
      context,
      title: 'Filters',
      builder: (sheetContext) => _FilterSheet(controller: widget.controller),
    );
  }
}

/// Filter sheet body: category chips apply live (like the kit); the date
/// range applies on the "Show N documents" button.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.controller});

  final ArchiveController controller;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _from = TextEditingController(
    text: widget.controller.dateFrom ?? '',
  );
  late final TextEditingController _to = TextEditingController(
    text: widget.controller.dateTo ?? '',
  );
  bool _fromError = false;
  bool _toError = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Same rule as the desktop sidebar: a bound applies only when the field
  /// is empty (clears it) or holds a complete valid YYYY-MM-DD date —
  /// anything else is invalid and the range is not applied.
  ({bool ok, String? value}) _bound(TextEditingController field) {
    final t = field.text.trim();
    if (t.isEmpty) return (ok: true, value: null);
    if (_isoDate.hasMatch(t) && DateTime.tryParse(t) != null) {
      return (ok: true, value: t);
    }
    return (ok: false, value: null);
  }

  void _apply() {
    final from = _bound(_from);
    final to = _bound(_to);
    if (!from.ok || !to.ok) {
      setState(() {
        _fromError = !from.ok;
        _toError = !to.ok;
      });
      return;
    }
    widget.controller.setDateRange(from.value, to.value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // The sheet surface doesn't avoid the keyboard itself; pad the content by
    // the view insets and cap the height so the fields stay reachable.
    final insets = MediaQuery.viewInsetsOf(context);
    final maxHeight = (MediaQuery.sizeOf(context).height - insets.bottom - 120)
        .clamp(220.0, 4000.0)
        .toDouble();
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final n = c.docs.length;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('Category', topMargin: 0),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MfChip(
                      label: 'All',
                      selected: c.category == null,
                      onTap: () => c.setCategory(null),
                    ),
                    for (final cat in kCategories)
                      MfChip(
                        label: cat,
                        selected: c.category == cat,
                        onTap: () => c.setCategory(cat),
                      ),
                  ],
                ),
                const _SectionLabel('Date range'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MfTextField(
                        label: 'From',
                        controller: _from,
                        mono: true,
                        error: _fromError,
                        message: _fromError
                            ? 'Use YYYY-MM-DD'
                            : 'e.g. 2026-01-31',
                        onChanged: (_) {
                          if (_fromError) setState(() => _fromError = false);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MfTextField(
                        label: 'To',
                        controller: _to,
                        mono: true,
                        error: _toError,
                        message: _toError
                            ? 'Use YYYY-MM-DD'
                            : 'e.g. 2026-01-31',
                        onChanged: (_) {
                          if (_toError) setState(() => _toError = false);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                MfButton(
                  fullWidth: true,
                  label: 'Show $n document${n == 1 ? '' : 's'}',
                  onPressed: _apply,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Loading placeholder: the kit's SkeletonCard with the brand's slow 1.6s
/// opacity pulse (never a spinner).
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  // Half the 1.6s cycle each way; repeat(reverse: true) closes the loop.
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
    Widget bar({
      double? width,
      double? widthFactor,
      required double height,
      double radius = 4,
    }) {
      final box = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: mf.surfaceInset,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
      if (widthFactor == null) {
        return Align(alignment: Alignment.centerLeft, child: box);
      }
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: box,
      );
    }

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mf.surfaceCard,
          border: Border.all(color: mf.border),
          borderRadius: BorderRadius.circular(MfRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 74,
              decoration: BoxDecoration(
                color: mf.surfaceInset,
                borderRadius: BorderRadius.circular(MfRadius.md),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 74,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    bar(widthFactor: 0.75, height: 14),
                    const SizedBox(height: 8),
                    bar(widthFactor: 0.45, height: 11),
                    const Spacer(),
                    bar(width: 80, height: 18, radius: MfRadius.full),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mono caps section label (the kit's SectionLabel: margin 20/0/8).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.topMargin = 20});

  final String text;
  final double topMargin;

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
