// my-flopy — desktop archive browse (grid/table, states).
// Source: design/ui_kits/desktop/kit.desktop.jsx

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
import '../design/widgets/mf_status_badge.dart';
import '../design/widgets/mf_toast.dart';

/// The archive main content: offline/empty states, the count + density
/// toolbar, and the document grid or table.
class ArchiveContent extends StatefulWidget {
  const ArchiveContent({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onGoUpload,
  });

  final ArchiveController controller;
  final void Function(DocumentSummary) onOpen;
  final VoidCallback onGoUpload;

  @override
  State<ArchiveContent> createState() => _ArchiveContentState();
}

class _ArchiveContentState extends State<ArchiveContent> {
  /// 'grid' | 'table'.
  String _density = 'grid';

  static const _gridPadding = EdgeInsets.fromLTRB(22, 14, 22, 28);
  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 260,
    mainAxisSpacing: 14,
    crossAxisSpacing: 14,
    mainAxisExtent: 280,
  );

  Future<void> _retry() async {
    await widget.controller.refresh();
    if (!mounted) return;
    if (widget.controller.state == ArchiveState.offline) {
      showMfToast(
        context,
        "Still can't reach your home server.",
        tone: MfToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final mf = context.mf;
        final controller = widget.controller;
        switch (controller.state) {
          case ArchiveState.offline:
            return Center(
              child: MfEmptyState(
                title: "Can't reach your home server",
                body:
                    'Your archive lives only on your own server. Check the '
                    'VPN connection and try again — nothing is stored '
                    'anywhere else.',
                icon: MfIcon(
                  MfGlyphs.wifiOff,
                  size: 44,
                  strokeWidth: 1.5,
                  color: mf.warn,
                ),
                action: MfButton(
                  variant: MfButtonVariant.secondary,
                  label: 'Try again',
                  onPressed: _retry,
                ),
              ),
            );
          case ArchiveState.empty:
            return Center(
              child: MfEmptyState(
                title: 'Nothing filed yet',
                body:
                    'Drop a scan here, or photograph a letter with your '
                    'phone.',
                action: MfButton(
                  label: 'Add your first letter',
                  icon: const MfIcon(MfGlyphs.upload, size: 18),
                  onPressed: widget.onGoUpload,
                ),
              ),
            );
          case ArchiveState.loading:
          case ArchiveState.populated:
          case ArchiveState.noMatches:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _toolbar(mf, controller),
                Expanded(child: _body(mf, controller)),
              ],
            );
        }
      },
    );
  }

  Widget _toolbar(MfColors mf, ArchiveController controller) {
    final count = controller.docs.length;
    final counter = controller.state == ArchiveState.loading
        ? 'Searching…'
        : '$count document${count == 1 ? '' : 's'}';
    final query = controller.query;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              query.isEmpty
                  ? counter
                  : '$counter · matching “$query” by words and meaning',
              style: MfType.sm.copyWith(color: mf.text2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          _densityToggle(mf),
        ],
      ),
    );
  }

  /// Grid/table segment: two icon buttons in one bordered rounded frame,
  /// active = accent-tint / accent (per kit toolbar).
  Widget _densityToggle(MfColors mf) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: mf.borderStrong),
        borderRadius: BorderRadius.circular(MfRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DensityButton(
            label: 'Grid view',
            glyph: MfGlyphs.grid,
            active: _density == 'grid',
            onTap: () => setState(() => _density = 'grid'),
          ),
          _DensityButton(
            label: 'Table view',
            glyph: MfGlyphs.rows,
            active: _density == 'table',
            onTap: () => setState(() => _density = 'table'),
          ),
        ],
      ),
    );
  }

  Widget _body(MfColors mf, ArchiveController controller) {
    if (controller.state == ArchiveState.loading) {
      return GridView.builder(
        padding: _gridPadding,
        gridDelegate: _gridDelegate,
        itemCount: 6,
        itemBuilder: (context, _) => const _SkeletonTile(),
      );
    }
    if (controller.state == ArchiveState.noMatches) {
      return SingleChildScrollView(
        child: Center(
          child: MfEmptyState(
            title: 'No matches',
            body:
                'Nothing matches “${controller.query}”. Try describing the '
                'letter instead — search also looks at meaning.',
          ),
        ),
      );
    }
    return _density == 'grid' ? _grid(controller) : _table(mf, controller);
  }

  Widget _grid(ArchiveController controller) {
    final client = AppConfigScope.of(context).client;
    return GridView.builder(
      padding: _gridPadding,
      gridDelegate: _gridDelegate,
      itemCount: controller.docs.length,
      itemBuilder: (context, i) {
        final doc = controller.docs[i];
        final done = doc.status == 'done';
        return MfDocumentCard(
          density: MfCardDensity.grid,
          title: doc.title,
          correspondent: doc.correspondent,
          date: doc.documentDate == null ? null : formatDate(doc.documentDate),
          category: doc.category,
          status: _status(doc.status),
          pages: doc.pageCount,
          image: done && client != null
              ? NetworkImage(
                  client.imageUri(doc.id, 1).toString(),
                  headers: client.authHeaders,
                )
              : null,
          onOpen: () => widget.onOpen(doc),
        );
      },
    );
  }

  static MfStatus _status(String status) => switch (status) {
    'queued' => MfStatus.queued,
    'processing' => MfStatus.processing,
    'failed' => MfStatus.error,
    _ => MfStatus.done,
  };

  // ── table density ────────────────────────────────────────────────
  Widget _table(MfColors mf, ArchiveController controller) {
    final header = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: mf.border)),
      ),
      child: _tableRowLayout(
        title: Text('TITLE', style: MfType.monoCaps.copyWith(color: mf.text3)),
        correspondent: Text(
          'CORRESPONDENT',
          style: MfType.monoCaps.copyWith(color: mf.text3),
        ),
        date: Text('DATE', style: MfType.monoCaps.copyWith(color: mf.text3)),
        category: Text(
          'CATEGORY',
          style: MfType.monoCaps.copyWith(color: mf.text3),
        ),
        pages: Text(
          'PAGES',
          textAlign: TextAlign.right,
          style: MfType.monoCaps.copyWith(color: mf.text3),
        ),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: mf.surfaceCard,
          border: Border.all(color: mf.border),
          borderRadius: BorderRadius.circular(MfRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            for (final doc in controller.docs)
              _TableRow(doc: doc, onOpen: () => widget.onOpen(doc)),
          ],
        ),
      ),
    );
  }

  /// Shared column layout for the table header and body rows.
  static Widget _tableRowLayout({
    required Widget title,
    required Widget correspondent,
    required Widget date,
    required Widget category,
    required Widget pages,
  }) {
    return Row(
      children: [
        Expanded(flex: 5, child: title),
        const SizedBox(width: 14),
        Expanded(flex: 3, child: correspondent),
        const SizedBox(width: 14),
        SizedBox(width: 100, child: date),
        const SizedBox(width: 14),
        SizedBox(
          width: 120,
          child: Align(alignment: Alignment.centerLeft, child: category),
        ),
        const SizedBox(width: 14),
        SizedBox(width: 48, child: pages),
      ],
    );
  }
}

class _DensityButton extends StatelessWidget {
  const _DensityButton({
    required this.label,
    required this.glyph,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String glyph;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              color: active ? mf.accentTint : mf.surfaceCard,
              child: MfIcon(
                glyph,
                size: 16,
                color: active ? mf.accent : mf.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One table row: serif title, correspondent, mono date, category chip and a
/// right-aligned page count; hover = one paper step, click opens the doc.
class _TableRow extends StatefulWidget {
  const _TableRow({required this.doc, required this.onOpen});

  final DocumentSummary doc;
  final VoidCallback onOpen;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final doc = widget.doc;
    final processing = doc.status != 'done';
    final title =
        doc.title ??
        (processing ? 'Reading your letter…' : 'Untitled document');
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            decoration: BoxDecoration(
              color: _hovered ? mf.surfaceHover : Colors.transparent,
              border: Border(bottom: BorderSide(color: mf.border)),
            ),
            child: _ArchiveContentState._tableRowLayout(
              title: Text(
                title,
                style: MfType.base.copyWith(
                  fontFamily: MfFonts.serif,
                  fontWeight: FontWeight.w600,
                  color: mf.text1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              correspondent: Text(
                doc.correspondent ?? '',
                style: MfType.sm.copyWith(color: mf.text2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              date: Text(
                doc.documentDate == null ? '' : formatDate(doc.documentDate),
                style: MfType.monoXs.copyWith(color: mf.text2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              category: doc.category == null
                  ? const SizedBox.shrink()
                  : MfChip(label: doc.category!),
              pages: Text(
                '${doc.pageCount}',
                textAlign: TextAlign.right,
                style: MfType.monoXs.copyWith(color: mf.text2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pulsing placeholder tile while the archive loads — the brand's slow
/// 1.6s pulse, never a spinner (design/readme.md "Motion").
class _SkeletonTile extends StatefulWidget {
  const _SkeletonTile();

  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
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
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        decoration: BoxDecoration(
          color: mf.surfaceCard,
          border: Border.all(color: mf.border),
          borderRadius: BorderRadius.circular(MfRadius.lg),
        ),
      ),
    );
  }
}
