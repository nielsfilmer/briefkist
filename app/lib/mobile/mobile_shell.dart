// my-flopy — mobile shell. Source: design/ui_kits/mobile/kit.mobile.jsx

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../app_config.dart';
import '../archive_controller.dart';
import '../design/mf_icons.dart';
import '../design/widgets/mf_app_header.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_tab_bar.dart';
import 'archive_screen.dart';
import 'document_detail_screen.dart';
import 'settings_screen.dart';

/// Phone layout: app header + active tab + bottom tab bar
/// (capture / archive / settings). Owns the [ArchiveController].
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  // Dev-only initial tab override for simulator QA (MF_TAB=archive).
  String _tab = const String.fromEnvironment('MF_TAB', defaultValue: 'capture');
  ArchiveController? _archive;
  FlopyClient? _client;

  /// Whether we already yanked the user to settings for this
  /// unconfigured episode (don't re-force on every dependency change).
  bool _forcedSettings = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = AppConfigScope.of(context).client;
    if (client == null) {
      // Not paired yet: nothing for the controller to talk to, and the only
      // useful tab is settings — other tabs show a not-configured state.
      _archive?.dispose();
      _archive = null;
      _client = null;
      if (!_forcedSettings) {
        _forcedSettings = true;
        _tab = 'settings';
      }
    } else if (!identical(client, _client)) {
      _forcedSettings = false;
      _client = client;
      final archive = _archive;
      if (archive == null) {
        _archive = ArchiveController(client);
      } else {
        archive.client = client; // connection settings changed → refetch
      }
    }
  }

  @override
  void dispose() {
    _archive?.dispose();
    super.dispose();
  }

  void _openDocument(DocumentSummary doc) {
    final client = _client;
    if (client == null) return;
    // Native idiom: detail is a pushed route rather than the kit's in-place
    // swap — the kit's back-button header maps to the route's own back.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailScreen(docId: doc.id, client: client),
      ),
    );
  }

  // Dev-only: lets simulator QA relaunches land on a document detail
  // (the simulator cannot be tapped programmatically).
  static const _qaOpenDoc = int.fromEnvironment('MF_OPEN_DOC');
  bool _qaOpened = false;

  void _maybeQaOpen() {
    if (_qaOpenDoc == 0 || _qaOpened) return;
    final client = _client;
    if (client == null) return;
    _qaOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DocumentDetailScreen(docId: _qaOpenDoc, client: client),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeQaOpen();
    final config = AppConfigScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false, // the tab bar pads the bottom inset itself
        child: ListenableBuilder(
          listenable: Listenable.merge([?_archive]),
          builder: (context, _) => Column(
            children: [
              MfAppHeader(connection: _connectionTone(config)),
              Expanded(child: _tabBody(config)),
              MfTabBar(
                active: _tab,
                onSelect: (id) => setState(() => _tab = id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ok while talking to the server, warn when the archive reports offline.
  /// Before pairing the mark is omitted — "connected · home" would be untrue
  /// (deliberate deviation: the kit always shows a mark; detail routes carry
  /// their own header with no mark, per the kit's `connection={null}`).
  MfPrivacyTone? _connectionTone(AppConfig config) {
    if (!config.isConfigured) return null;
    return _archive?.state == ArchiveState.offline
        ? MfPrivacyTone.warn
        : MfPrivacyTone.ok;
  }

  Widget _tabBody(AppConfig config) {
    switch (_tab) {
      case 'archive':
        final archive = _archive;
        if (archive == null) return _notConfigured();
        return ArchiveScreen(
          controller: archive,
          onOpen: _openDocument,
          onGoCapture: () => setState(() => _tab = 'capture'),
        );
      case 'settings':
        return const SettingsScreen();
      default: // capture — placeholder until the capture PR lands.
        if (!config.isConfigured) return _notConfigured();
        return _capturePlaceholder();
    }
  }

  Widget _capturePlaceholder() {
    return Center(
      child: SingleChildScrollView(
        child: MfEmptyState(
          icon: const MfIcon(MfGlyphs.camera, size: 44),
          title: 'Capture',
          body:
              'Photograph letters with this phone — coming in the next '
              'update.',
        ),
      ),
    );
  }

  Widget _notConfigured() {
    return Center(
      child: SingleChildScrollView(
        child: MfEmptyState(
          title: 'Pair with your server',
          body: 'Set the server address in settings to browse your archive.',
          action: MfButton(
            label: 'Open settings',
            onPressed: () => setState(() => _tab = 'settings'),
          ),
        ),
      ),
    );
  }
}
