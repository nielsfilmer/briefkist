// Briefkist — settings screen. Source: design/ui_kits/mobile/kit.mobile.jsx
// (SettingsScreen + PairSheet).

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../app_config.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_chip.dart';
import '../design/widgets/mf_dialog.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_sheet.dart';
import '../design/widgets/mf_text_field.dart';
import '../design/widgets/mf_toast.dart';

// 76 clears the mobile tab bar (mf_toast.dart guidance).
const _kToastOffset = 76.0;

/// The settings tab: server card, connection fields, paired devices
/// (list + revoke + the pair-a-new-device QR sheet), appearance.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _server = TextEditingController();
  final _token = TextEditingController();
  bool _seeded = false;

  /// The client the device list below belongs to; refetched when the
  /// connection changes.
  FlopyClient? _devicesClient;
  List<PairedDevice>? _devices;

  /// The device name this phone's token authenticates as (whoami), fetched
  /// once per connection; null until known (then every row gets a Revoke —
  /// the server 409s a self-revoke, so nothing breaks, we just can't mark
  /// "this device").
  String? _selfDevice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = AppConfigScope.of(context);
    if (!_seeded) {
      _seeded = true;
      _server.text = config.serverUrl;
      _token.text = config.token;
    }
    final client = config.client;
    if (!identical(client, _devicesClient)) {
      _devicesClient = client;
      _devices = null;
      _selfDevice = null;
      if (client != null) {
        _loadDevices(client);
        _loadSelf(client);
      }
    }
  }

  @override
  void dispose() {
    _server.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = AppConfigScope.of(context);
    await config.setConnection(serverUrl: _server.text, token: _token.text);
    if (!mounted) return;
    showMfToast(context, 'Saved.', bottomOffset: _kToastOffset);
  }

  // ── devices ────────────────────────────────────────────────

  Future<void> _loadDevices(FlopyClient client) async {
    try {
      final devices = await client.listDevices();
      if (!mounted || !identical(client, _devicesClient)) return;
      setState(() => _devices = devices);
    } on ServerUnreachable {
      // Offline: hide the section quietly — the server card's "not
      // configured / connected" mark already tells the connection story.
      if (!mounted || !identical(client, _devicesClient)) return;
      setState(() => _devices = null);
    } on ApiError {
      if (!mounted || !identical(client, _devicesClient)) return;
      setState(() => _devices = null);
    }
  }

  Future<void> _loadSelf(FlopyClient client) async {
    try {
      final self = await client.whoami();
      if (!mounted || !identical(client, _devicesClient)) return;
      setState(() => _selfDevice = self);
    } on ServerUnreachable {
      // Quiet — see [_selfDevice].
    } on ApiError {
      // Quiet — see [_selfDevice].
    }
  }

  Future<void> _confirmRevoke(FlopyClient client, String name) async {
    final confirmed = await showMfDialog<bool>(
      context,
      title: 'Revoke $name?',
      body: const Text('That device loses access immediately.'),
      actions: [
        MfButton(
          variant: MfButtonVariant.ghost,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        MfButton(
          variant: MfButtonVariant.destructive,
          label: 'Revoke',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    // The connection config may have changed while the dialog was open —
    // never revoke through a client that is no longer the current one.
    if (confirmed != true || !mounted || !identical(client, _devicesClient)) {
      return;
    }
    try {
      await client.revokeDevice(name);
    } on ServerUnreachable {
      if (!mounted) return;
      showMfToast(
        context,
        "Can't reach your home server — nothing was revoked.",
        tone: MfToastTone.error,
        bottomOffset: _kToastOffset,
      );
      return;
    } on ApiError {
      if (!mounted) return;
      // 409 = this phone's own token (shouldn't be reachable — the row shows
      // "this device" instead of Revoke once whoami resolves).
      showMfToast(
        context,
        "The server refused to revoke '$name'.",
        tone: MfToastTone.error,
        bottomOffset: _kToastOffset,
      );
      return;
    }
    if (!mounted) return;
    showMfToast(context, 'Revoked.', bottomOffset: _kToastOffset);
    _loadDevices(client);
  }

  void _openPairSheet(FlopyClient client, String serverUrl) {
    showMfSheet<void>(
      context,
      title: 'Pair a new device',
      builder: (_) => _PairSheetBody(
        client: client,
        serverUrl: serverUrl,
        // Refresh the list behind the sheet as soon as the token is minted.
        onMinted: () => _loadDevices(client),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final config = AppConfigScope.of(context);
    final configured = config.isConfigured;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionLabel('Your server', topMargin: 6),
        _card(
          mf,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: mf.accentTint,
                  borderRadius: BorderRadius.circular(MfRadius.md),
                ),
                alignment: Alignment.center,
                child: MfIcon(MfGlyphs.home, size: 20, color: mf.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      configured ? config.serverHost : 'Not configured',
                      style: MfType.base.copyWith(
                        color: mf.text1,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All processing happens here.',
                      style: MfType.sm.copyWith(color: mf.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MfPrivacyMark(
                tone: configured ? MfPrivacyTone.ok : MfPrivacyTone.warn,
                label: configured ? 'connected' : 'not configured',
              ),
            ],
          ),
        ),
        const _SectionLabel('Connection'),
        _card(
          mf,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MfTextField(
                label: 'Server address',
                controller: _server,
                message: 'e.g. 192.168.x.x:8484',
              ),
              const SizedBox(height: 12),
              MfTextField(
                label: 'Device token',
                mono: true,
                controller: _token,
                message: 'Paste the token minted on your server.',
              ),
              const SizedBox(height: 14),
              MfButton(label: 'Save', fullWidth: true, onPressed: _save),
            ],
          ),
        ),
        // Devices: only once the paired-device list actually loaded —
        // unconfigured/offline hides the section quietly.
        if (_devicesClient != null && _devices != null) ...[
          const _SectionLabel('Devices'),
          _card(
            mf,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, device) in _devices!.indexed)
                  _deviceRow(mf, device, topBorder: i > 0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  decoration: _devices!.isEmpty
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: mf.border)),
                        ),
                  child: MfButton(
                    variant: MfButtonVariant.secondary,
                    fullWidth: true,
                    icon: const MfIcon(MfGlyphs.qr, size: 18),
                    label: 'Pair a new device',
                    onPressed: () =>
                        _openPairSheet(_devicesClient!, config.serverUrl),
                  ),
                ),
              ],
            ),
          ),
        ],
        const _SectionLabel('Appearance'),
        _card(
          mf,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              for (final (mode, label) in const [
                (ThemeMode.light, 'light'),
                (ThemeMode.dark, 'dark'),
                (ThemeMode.system, 'system'),
              ]) ...[
                if (mode != ThemeMode.light) const SizedBox(width: 8),
                MfChip(
                  label: label,
                  selected: config.themeMode == mode,
                  onTap: () => config.setThemeMode(mode),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: Text(
              'Briefkist 1.0 · self-hosted',
              style: MfType.monoXs.copyWith(color: mf.text3),
            ),
          ),
        ),
      ],
    );
  }

  /// One paired-device row (the kit's rowS: 13/14 padding, base name, mono-xs
  /// paired date) + either "this device" or a Revoke affordance.
  Widget _deviceRow(
    MfColors mf,
    PairedDevice device, {
    required bool topBorder,
  }) {
    final isSelf = _selfDevice != null && device.name == _selfDevice;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      decoration: topBorder
          ? BoxDecoration(
              border: Border(top: BorderSide(color: mf.border)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              device.name,
              style: MfType.base.copyWith(color: mf.text1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            device.created == null
                ? 'paired earlier' // pre-pairing tokens have no created date
                : 'paired ${formatDate(device.created)}',
            style: MfType.monoXs.copyWith(color: mf.text3),
          ),
          const SizedBox(width: 12),
          if (isSelf)
            Text('this device', style: MfType.sm.copyWith(color: mf.text3))
          else
            MfButton(
              variant: MfButtonVariant.destructive,
              size: MfButtonSize.sm,
              label: 'Revoke',
              onPressed: () => _confirmRevoke(_devicesClient!, device.name),
            ),
        ],
      ),
    );
  }

  Widget _card(
    MfColors mf, {
    required EdgeInsets padding,
    required Widget child,
  }) {
    return Container(
      padding: padding,
      clipBehavior: padding == EdgeInsets.zero ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
      ),
      child: child,
    );
  }
}

/// The pair-a-new-device sheet (kit: PairSheet), made honest: first mint a
/// token for a named device, then show the QR + token it can pair with.
class _PairSheetBody extends StatefulWidget {
  const _PairSheetBody({
    required this.client,
    required this.serverUrl,
    required this.onMinted,
  });

  final FlopyClient client;

  /// As configured (what this phone connects with) — it goes into the QR
  /// payload verbatim for the new device to use.
  final String serverUrl;

  /// Called once the token is minted, so the device list can refresh.
  final VoidCallback onMinted;

  @override
  State<_PairSheetBody> createState() => _PairSheetBodyState();
}

class _PairSheetBodyState extends State<_PairSheetBody> {
  final _name = TextEditingController();
  TextEditingController? _mintedToken;
  MintedDevice? _minted;
  String? _nameError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _mintedToken?.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give the device a name.');
      return;
    }
    // The QR embeds widget.serverUrl verbatim; a loopback address only
    // resolves on THIS device, so the minted code could never connect
    // another one (PR #42 finding 2).
    if (AppConfig.isLoopbackServerUrl(widget.serverUrl)) {
      setState(
        () => _nameError =
            'This device reaches the server at a loopback address — another '
            "device can't. Set the server's LAN address in Connection first.",
      );
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
    });
    final MintedDevice minted;
    try {
      minted = await widget.client.addDevice(name);
    } on ServerUnreachable {
      if (!mounted) return;
      setState(() => _busy = false);
      showMfToast(
        context,
        "Can't reach your home server.",
        tone: MfToastTone.error,
      );
      return;
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _nameError = e.status == 409
            ? 'That name is taken.'
            : 'The server refused that name.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _minted = minted;
      // The token is shown exactly once: the server never returns it again
      // (GET /api/devices lists names only), so this sheet is the only place
      // it can be scanned or copied from.
      _mintedToken = TextEditingController(text: minted.token);
    });
    widget.onMinted();
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    // The sheet sits at the screen bottom: pad the keyboard inset so the
    // name field stays visible while typing.
    return AnimatedPadding(
      duration: MfMotion.fast,
      curve: MfMotion.curve,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _minted == null ? _mintStep() : _qrStep(mf),
    );
  }

  Widget _mintStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MfTextField(
          label: 'Device name',
          controller: _name,
          error: _nameError != null,
          message: _nameError ?? "e.g. 'kitchen-ipad'",
        ),
        const SizedBox(height: 14),
        MfButton(
          label: 'Create pairing code',
          fullWidth: true,
          onPressed: _busy ? null : _create,
        ),
      ],
    );
  }

  Widget _qrStep(MfColors mf) {
    final minted = _minted!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'On the new device, open Briefkist and scan this code. The device '
          'gets its own token — you can revoke it any time.',
          style: MfType.base.copyWith(color: mf.text2),
        ),
        const SizedBox(height: 14),
        Center(
          // Black-on-white regardless of theme: scanners need contrast, so
          // the QR is never themed (white-backed box, default black modules).
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: mf.borderStrong),
              borderRadius: BorderRadius.circular(MfRadius.md),
            ),
            child: QrImageView(
              data: pairingPayload(
                serverUrl: widget.serverUrl,
                token: minted.token,
              ),
              size: 200,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              semanticsLabel: 'Pairing code for ${minted.name}',
            ),
          ),
        ),
        const SizedBox(height: 14),
        MfTextField(
          label: 'Or share a token',
          mono: true,
          controller: _mintedToken,
        ),
        const SizedBox(height: 16),
        const Center(child: MfPrivacyMark()),
        const SizedBox(height: 4),
      ],
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
