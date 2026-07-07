// Briefkist — mobile shell. Source: design/ui_kits/mobile/kit.mobile.jsx

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../app_config.dart';
import '../archive_controller.dart';
import '../design/widgets/mf_app_header.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_tab_bar.dart';
import '../design/widgets/mf_toast.dart';
import '../uploads_controller.dart';
import 'archive_screen.dart';
import 'capture_screen.dart';
import 'document_detail_screen.dart';
import 'onboarding_screen.dart';
import 'scan_pairing_screen.dart';
import 'settings_screen.dart';

/// Phone layout: app header + active tab + bottom tab bar
/// (capture / archive / settings). Owns the [ArchiveController] and the
/// [UploadsController].
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  // Dev-only initial tab override for simulator QA (MF_TAB=archive).
  String _tab = const String.fromEnvironment('MF_TAB', defaultValue: 'capture');
  ArchiveController? _archive;
  UploadsController? _uploads;
  FlopyClient? _client;

  /// Whether the user finished (or skipped past) the onboarding walkthrough
  /// this unconfigured episode — after that, capture/archive show the plain
  /// 'Pair with your server' empty state instead of looping onboarding.
  bool _onboarded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = AppConfigScope.of(context).client;
    if (client == null) {
      // Not paired yet: nothing for the controllers to talk to — the
      // capture/archive tabs show onboarding (settings stays reachable via
      // the tab bar; no forced tab switch).
      _archive?.dispose();
      _archive = null;
      _uploads?.dispose();
      _uploads = null;
      _client = null;
    } else if (!identical(client, _client)) {
      _client = client;
      final archive = _archive;
      if (archive == null) {
        _archive = ArchiveController(client);
      } else {
        archive.client = client; // connection settings changed → refetch
      }
      final uploads = _uploads;
      if (uploads == null) {
        _uploads = UploadsController(client);
      } else {
        uploads.client = client;
      }
    }
  }

  @override
  void dispose() {
    _archive?.dispose();
    _uploads?.dispose();
    super.dispose();
  }

  void _openDocument(DocumentSummary doc) => _openDocumentById(doc.id);

  void _openDocumentById(int docId) {
    final client = _client;
    if (client == null) return;
    // Native idiom: detail is a pushed route rather than the kit's in-place
    // swap — the kit's back-button header maps to the route's own back.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailScreen(docId: docId, client: client),
      ),
    );
  }

  void _selectTab(String id) {
    // A letter uploaded on the capture tab should be there when the user
    // looks: refresh the archive whenever they switch to it.
    if (id == 'archive' && _tab != 'archive') _archive?.refresh();
    // Documents uploaded by other devices only show up when this screen
    // polls; returning to the tab is the natural refresh point (QA, PR #39).
    if (id == 'capture' && _tab != 'capture') _uploads?.refresh();
    setState(() => _tab = id);
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

  /// Whether the active tab shows the onboarding walkthrough instead of its
  /// regular body (unconfigured, not yet walked through, not on settings).
  bool _showsOnboarding(AppConfig config) =>
      !config.isConfigured && !_onboarded && _tab != 'settings';

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
              // The kit shows onboarding chrome-free (no header); the tab
              // bar stays so settings remains reachable.
              if (!_showsOnboarding(config))
                MfAppHeader(connection: _connectionTone(config)),
              Expanded(child: _tabBody()),
              MfTabBar(active: _tab, onSelect: _selectTab),
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

  Widget _tabBody() {
    switch (_tab) {
      case 'archive':
        final archive = _archive;
        if (archive == null) return _unconfiguredBody();
        return ArchiveScreen(
          controller: archive,
          onOpen: _openDocument,
          onGoCapture: () => setState(() => _tab = 'capture'),
        );
      case 'settings':
        return const SettingsScreen();
      default: // capture
        final uploads = _uploads;
        if (uploads == null) return _unconfiguredBody();
        return CaptureScreen(uploads: uploads, onOpenDoc: _openDocumentById);
    }
  }

  /// Push the full-screen QR scanner; a scanned code pairs this phone with
  /// the server, the paste fallback routes to manual entry in settings.
  Future<void> _scanPairingCode() async {
    final result = await Navigator.of(context).push<ScanPairingResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ScanPairingScreen(),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case ScanPairingScanned(:final serverUrl, :final token):
        await AppConfigScope.of(
          context,
        ).setConnection(serverUrl: serverUrl, token: token);
        if (!mounted) return;
        // 76 clears the mobile tab bar (mf_toast.dart guidance).
        showMfToast(context, 'Paired with your server.', bottomOffset: 76);
        setState(() => _tab = 'capture');
      case ScanPairingPasteFallback():
        setState(() => _tab = 'settings');
      case null:
        break; // closed the scanner without pairing
    }
  }

  /// Capture/archive with no server configured: the onboarding walkthrough
  /// first, the plain pairing empty state once it's been dismissed.
  Widget _unconfiguredBody() {
    if (_onboarded) return _notConfigured();
    return OnboardingScreen(
      onScan: _scanPairingCode,
      onPair: () => setState(() => _tab = 'settings'),
      // 'Open the camera' on the last step: land on capture — still
      // unconfigured, so it shows the pairing empty state (not the loop).
      onDone: () => setState(() {
        _onboarded = true;
        _tab = 'capture';
      }),
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
