// my-flopy — desktop shell: top bar + sidebar + main content.
// Source: design/ui_kits/desktop/kit.desktop.jsx

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../app_config.dart';
import '../archive_controller.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_icon_button.dart';
import '../design/widgets/mf_mark.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_search_input.dart';
import '../design/widgets/mf_select.dart';
import '../design/widgets/mf_text_field.dart';
import '../uploads_controller.dart';
import 'archive_content.dart';
import 'detail_content.dart';
import 'settings_content.dart';
import 'upload_content.dart';

/// The desktop (macOS) layout per the kit's DesktopApp: a 60px top bar over a
/// Row of sidebar + main. Owns the nav state, the selected document, and the
/// [ArchiveController] built from the configured client.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  /// 'archive' | 'upload' | 'settings'.
  String _nav = 'archive';

  /// Non-null replaces the main content with the document detail.
  int? _docId;

  FlopyClient? _client;
  ArchiveController? _controller;
  UploadsController? _uploads;
  ArchiveState? _lastSeenState;
  List<Correspondent> _correspondents = const [];

  final _searchController = TextEditingController();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  bool _dateFromInvalid = false;
  bool _dateToInvalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = AppConfigScope.of(context).client;
    if (identical(client, _client)) return;
    _client = client;
    if (client == null) {
      _controller?.removeListener(_onArchiveChanged);
      _controller?.dispose();
      _controller = null;
      _uploads?.dispose();
      _uploads = null;
      _correspondents = const [];
      _docId = null;
    } else if (_controller == null) {
      _controller = ArchiveController(client)..addListener(_onArchiveChanged);
      _uploads = UploadsController(client);
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _dateFromInvalid = false;
      _dateToInvalid = false;
      _loadCorrespondents();
    } else {
      // Connection settings changed: keep the filters, swap the client.
      _controller!.client = client;
      _uploads!.client = client;
      _loadCorrespondents();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onArchiveChanged);
    _controller?.dispose();
    _uploads?.dispose();
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  void _onArchiveChanged() {
    final state = _controller?.state;
    // A completed refresh may have filed new correspondents — reload the
    // sidebar options alongside it.
    if (_lastSeenState == ArchiveState.loading &&
        state != ArchiveState.loading &&
        state != ArchiveState.offline) {
      _loadCorrespondents();
    }
    _lastSeenState = state;
    if (mounted) setState(() {});
  }

  Future<void> _loadCorrespondents() async {
    final client = _client;
    if (client == null) return;
    try {
      final list = await client.listCorrespondents();
      if (!mounted || !identical(client, _client)) return;
      setState(() => _correspondents = list);
    } on ServerUnreachable {
      // Keep whatever we had; the archive state already shows offline.
    } on ApiError {
      // Same — the sidebar just keeps its last known options.
    }
  }

  // ── date-range input ─────────────────────────────────────────────
  // MfTextField has no onSubmitted, so a change applies as soon as both
  // fields hold either nothing or a complete YYYY-MM-DD date — never while
  // a date is still being typed. A non-empty field that isn't a full ISO
  // date shows the error tone instead of being silently ignored.
  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  ({bool ok, String? value}) _parseDateInput(String text) {
    final t = text.trim();
    if (t.isEmpty) return (ok: true, value: null);
    if (_isoDate.hasMatch(t) && DateTime.tryParse(t) != null) {
      return (ok: true, value: t);
    }
    return (ok: false, value: null);
  }

  void _maybeApplyDateRange() {
    final controller = _controller;
    if (controller == null) return;
    final from = _parseDateInput(_dateFromController.text);
    final to = _parseDateInput(_dateToController.text);
    if (_dateFromInvalid != !from.ok || _dateToInvalid != !to.ok) {
      setState(() {
        _dateFromInvalid = !from.ok;
        _dateToInvalid = !to.ok;
      });
    }
    if (!from.ok || !to.ok) return;
    if (from.value == controller.dateFrom && to.value == controller.dateTo) {
      return;
    }
    controller.setDateRange(from.value, to.value);
  }

  // ── navigation ───────────────────────────────────────────────────
  void _goTo(String nav) {
    // Newly filed documents must appear when the user returns to the archive.
    if (nav == 'archive' && _nav != 'archive') _controller?.refresh();
    setState(() {
      _nav = nav;
      _docId = null; // per kit: changing screen closes the open document
    });
  }

  void _openDocument(DocumentSummary doc) => setState(() => _docId = doc.id);

  @override
  Widget build(BuildContext context) {
    final config = AppConfigScope.of(context);
    final configured = config.isConfigured;
    // Without a server there is nothing to show — force settings.
    final nav = configured ? _nav : 'settings';
    final docId = configured ? _docId : null;
    final state = _controller?.state;
    final offline = state == ArchiveState.offline;
    final host = config.serverHost;

    final showSearch =
        configured &&
        docId == null &&
        nav == 'archive' &&
        state != ArchiveState.empty &&
        state != ArchiveState.offline &&
        state != ArchiveState.error;
    // Kit behavior: no sidebar on the detail and settings screens.
    final showSidebar = configured && docId == null && nav != 'settings';

    final Widget main;
    final client = _client;
    final controller = _controller;
    if (docId != null && client != null) {
      main = DetailContent(
        key: ValueKey(docId),
        docId: docId,
        client: client,
        onBack: () => setState(() => _docId = null),
      );
    } else if (nav == 'settings') {
      main = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!configured) _connectHint(context),
          Expanded(child: SettingsContent(onBack: () => _goTo('archive'))),
        ],
      );
    } else if (nav == 'upload' && _uploads != null) {
      main = UploadContent(
        uploads: _uploads!,
        onOpenDoc: (id) => setState(() => _docId = id),
      );
    } else if (controller != null) {
      main = ArchiveContent(
        controller: controller,
        onOpen: _openDocument,
        onGoUpload: () => _goTo('upload'),
      );
    } else {
      main = const SizedBox.shrink();
    }

    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            searchController: _searchController,
            onQuery: (q) => _controller?.setQuery(q),
            showSearch: showSearch,
            connection: !configured
                ? MfPrivacyTone.neutral
                : offline
                ? MfPrivacyTone.warn
                : MfPrivacyTone.ok,
            onSettings: () => _goTo('settings'),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSidebar && controller != null)
                  _Sidebar(
                    nav: nav,
                    onNav: _goTo,
                    category: controller.category,
                    onCategory: controller.setCategory,
                    correspondents: [for (final c in _correspondents) c.name],
                    correspondent: controller.correspondent,
                    onCorrespondent: controller.setCorrespondent,
                    dateFromController: _dateFromController,
                    dateToController: _dateToController,
                    dateFromInvalid: _dateFromInvalid,
                    dateToInvalid: _dateToInvalid,
                    onDateChanged: _maybeApplyDateRange,
                    host: host,
                    offline: offline,
                  ),
                Expanded(child: main),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shown above the settings screen until a server is configured.
  Widget _connectHint(BuildContext context) {
    final mf = context.mf;
    return Container(
      margin: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
      ),
      child: Row(
        children: [
          MfIcon(MfGlyphs.info, size: 18, color: mf.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Not connected yet — enter your server address and device '
              'token below to open your archive.',
              style: MfType.base.copyWith(color: mf.text2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────
// Per kit TopBar: height 60, padding 0/20, 1px bottom border, gap 20;
// wordmark · centered search (max-width 540) · privacy mark · settings gear.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchController,
    required this.onQuery,
    required this.showSearch,
    required this.connection,
    required this.onSettings,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onQuery;
  final bool showSearch;
  final MfPrivacyTone connection;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: mf.surfacePage,
        border: Border(bottom: BorderSide(color: mf.border)),
      ),
      child: Row(
        children: [
          const MfWordmark(),
          const SizedBox(width: 20),
          Expanded(
            child: Center(
              child: showSearch
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: MfSearchInput(
                        controller: searchController,
                        onChanged: onQuery,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 20),
          MfPrivacyMark(tone: connection),
          const SizedBox(width: 20),
          MfIconButton(
            label: 'Settings',
            onPressed: onSettings,
            child: const MfIcon(MfGlyphs.gear, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────
// Per kit Sidebar: width 230, 1px right border, padding 16/14. Nav buttons,
// then Category / Correspondent / Date range filter groups, privacy mark at
// the bottom.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.nav,
    required this.onNav,
    required this.category,
    required this.onCategory,
    required this.correspondents,
    required this.correspondent,
    required this.onCorrespondent,
    required this.dateFromController,
    required this.dateToController,
    required this.dateFromInvalid,
    required this.dateToInvalid,
    required this.onDateChanged,
    required this.host,
    required this.offline,
  });

  final String nav;
  final ValueChanged<String> onNav;
  final String? category;
  final ValueChanged<String?> onCategory;
  final List<String> correspondents;
  final String? correspondent;
  final ValueChanged<String?> onCorrespondent;
  final TextEditingController dateFromController;
  final TextEditingController dateToController;
  final bool dateFromInvalid;
  final bool dateToInvalid;
  final VoidCallback onDateChanged;
  final String host;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: mf.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavButton(
                    label: 'Archive',
                    glyph: MfGlyphs.archive,
                    active: nav == 'archive',
                    onTap: () => onNav('archive'),
                  ),
                  const SizedBox(height: 2),
                  _NavButton(
                    label: 'Add documents',
                    glyph: MfGlyphs.upload,
                    active: nav == 'upload',
                    onTap: () => onNav('upload'),
                  ),
                  const MfSideLabel('Category'),
                  _CategoryRow(
                    label: 'All categories',
                    selected: category == null,
                    onTap: () => onCategory(null),
                  ),
                  for (final c in kCategories) ...[
                    const SizedBox(height: 1),
                    _CategoryRow(
                      label: c,
                      selected: category == c,
                      onTap: () => onCategory(c),
                    ),
                  ],
                  const MfSideLabel('Correspondent'),
                  MfSelect(
                    options: correspondents,
                    value: correspondent,
                    placeholder: 'Any',
                    onChanged: onCorrespondent,
                  ),
                  const MfSideLabel('Date range'),
                  // MfTextField has no placeholder slot, so the ISO format
                  // hint lives in the message line under each field.
                  MfTextField(
                    controller: dateFromController,
                    mono: true,
                    error: dateFromInvalid,
                    message: dateFromInvalid
                        ? 'Use YYYY-MM-DD'
                        : 'from · YYYY-MM-DD',
                    onChanged: (_) => onDateChanged(),
                  ),
                  const SizedBox(height: 8),
                  MfTextField(
                    controller: dateToController,
                    mono: true,
                    error: dateToInvalid,
                    message: dateToInvalid
                        ? 'Use YYYY-MM-DD'
                        : 'to · YYYY-MM-DD',
                    onChanged: (_) => onDateChanged(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: offline
                ? const MfPrivacyMark(tone: MfPrivacyTone.warn)
                : MfPrivacyMark(
                    tone: MfPrivacyTone.ok,
                    label: '$host · connected',
                  ),
          ),
        ],
      ),
    );
  }
}

/// Mono-caps side label, per the kit's SideLabel (margin 22/0/8).
class MfSideLabel extends StatelessWidget {
  const MfSideLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: MfType.monoCaps.copyWith(color: context.mf.text3),
      ),
    );
  }
}

/// Sidebar nav item per the kit's navItem: padding 9/12, radius md, 10px
/// icon gap; active = accent-tint background + accent semibold, hover one
/// paper step.
class _NavButton extends StatefulWidget {
  const _NavButton({
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
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final bg = widget.active
        ? mf.accentTint
        : _hovered
        ? mf.surfaceHover
        : Colors.transparent;
    final fg = widget.active ? mf.accent : mf.text2;
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
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(MfRadius.md),
            ),
            child: Row(
              children: [
                MfIcon(widget.glyph, size: 16, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: MfType.base.copyWith(
                      color: fg,
                      fontWeight: widget.active
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Category filter row: padding 6/12, radius md; selected = surface-hover
/// background + text-1. The trailing slot is the kit's per-category count.
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final bg = widget.selected || _hovered
        ? mf.surfaceHover
        : Colors.transparent;
    final fg = widget.selected ? mf.text1 : mf.text2;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(MfRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: MfType.sm.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Per-category counts need a categories endpoint — follow-up.
                // The slot keeps the kit's layout shape (mono xs, text-3).
                Text('', style: MfType.monoXs.copyWith(color: mf.text3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
