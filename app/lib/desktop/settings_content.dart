// Briefkist — desktop settings (connection, pairing, server, preferences).
// Source: design/ui_kits/desktop/kit.desktop.jsx (SettingsContent).

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../app_config.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_dialog.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_select.dart';
import '../design/widgets/mf_text_field.dart';
import '../design/widgets/mf_toast.dart';

/// v1-pragmatic settings: manual connection (server address + device token),
/// the kit's "Pair a device" QR card + paired-devices list (tracker #29),
/// the server card, and appearance/language preferences.
///
/// Deliberate kit deviation: the kit mocks an always-visible QR, but tokens
/// are minted per named device (server enforces name uniqueness), so the QR
/// area starts as a placeholder and a code is minted on demand from the
/// "Device name" field.
class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  final _serverController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _prefilled = false;

  // ── pairing state ──────────────────────────────────────────
  final _deviceNameController = TextEditingController();
  String? _deviceNameError;
  bool _minting = false;

  /// The freshly minted device, if any — the only moment its token exists
  /// client-side (the server returns it exactly once, models.dart).
  MintedDevice? _minted;
  bool _showToken = false;

  /// The client the device data below was fetched with; identity changes
  /// whenever the connection config changes (AppConfig rebuilds its client).
  FlopyClient? _devicesClient;
  List<PairedDevice>? _devices;
  String? _thisDevice;
  bool _devicesOffline = false;

  /// The server answered the device-list call but refused it (401/403, …):
  /// hide the pairing sections quietly, like mobile (PR #42 finding 3).
  bool _devicesDenied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = AppConfigScope.of(context);
    if (!_prefilled) {
      _prefilled = true;
      _serverController.text = config.serverUrl;
      _tokenController.text = config.token;
    }
    if (!identical(config.client, _devicesClient)) {
      _devicesClient = config.client;
      _minted = null; // a minted code belongs to the previous server
      _showToken = false;
      _devices = null;
      _thisDevice = null;
      _devicesOffline = false;
      _devicesDenied = false;
      _refreshDevices();
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _tokenController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = AppConfigScope.of(context);
    await config.setConnection(
      serverUrl: _serverController.text,
      token: _tokenController.text,
    );
    if (!mounted) return;
    showMfToast(context, 'Connection saved.');
  }

  // ── pairing actions ────────────────────────────────────────

  Future<void> _refreshDevices() async {
    final client = _devicesClient;
    if (client == null) return;
    List<PairedDevice> devices;
    try {
      devices = await client.listDevices();
    } on ServerUnreachable {
      if (!mounted || !identical(client, _devicesClient)) return;
      setState(() => _devicesOffline = true);
      return;
    } on ApiError {
      // The server answered but refused (401/403, …) — that is NOT
      // "unreachable", so don't claim it is. Hide the pairing sections
      // quietly, like mobile does (PR #42 finding 3).
      if (!mounted || !identical(client, _devicesClient)) return;
      setState(() {
        _devices = null;
        _devicesOffline = false;
        _devicesDenied = true;
      });
      return;
    }
    String? thisDevice;
    try {
      thisDevice = await client.whoami();
    } on Exception {
      // Only a genuinely failed call lands here. Tokenless loopback
      // bootstrap does NOT throw: the server returns the
      // '_bootstrap_loopback' sentinel, which can never collide with a real
      // device (validate_name forbids leading underscores), so the
      // "this device" marker simply never matches then.
      thisDevice = null;
    }
    if (!mounted || !identical(client, _devicesClient)) return;
    setState(() {
      _devices = devices;
      _thisDevice = thisDevice;
      _devicesOffline = false;
      _devicesDenied = false;
    });
  }

  Future<void> _mint() async {
    final client = _devicesClient;
    if (client == null || _minting) return;
    final name = _deviceNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _deviceNameError = 'Give the device a name.');
      return;
    }
    // A pairing code embeds the configured server URL verbatim; a loopback
    // address only resolves on THIS machine, so the minted code could never
    // connect another device (PR #42 finding 2).
    if (AppConfig.isLoopbackServerUrl(AppConfigScope.of(context).serverUrl)) {
      setState(
        () => _deviceNameError =
            'This device reaches the server at a loopback address — another '
            "device can't. Set the server's LAN address in Connection first.",
      );
      return;
    }
    setState(() {
      _minting = true;
      _deviceNameError = null;
    });
    try {
      final minted = await client.addDevice(name);
      if (!mounted || !identical(client, _devicesClient)) return;
      setState(() {
        _minted = minted;
        _showToken = false;
        _minting = false;
        _deviceNameController.clear();
      });
      // The device is listed the moment its token is minted — refresh now.
      _refreshDevices();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _minting = false;
        _deviceNameError = e.status == 409
            ? 'That name is taken.'
            : 'The server refused (${e.status}).';
      });
    } on ServerUnreachable {
      if (!mounted) return;
      setState(() => _minting = false);
      showMfToast(
        context,
        'Server unreachable — try again on your home network.',
        tone: MfToastTone.error,
      );
    }
  }

  Future<void> _revoke(String name) async {
    final client = _devicesClient;
    if (client == null) return;
    final confirmed = await showMfDialog<bool>(
      context,
      title: 'Revoke device',
      body: Text('Revoke $name? That device loses access immediately.'),
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
    if (confirmed != true || !mounted || !identical(client, _devicesClient)) {
      return;
    }
    try {
      await client.revokeDevice(name);
    } on ApiError catch (e) {
      if (!mounted) return;
      showMfToast(
        context,
        e.status == 409
            ? "This device can't revoke itself."
            : 'Could not revoke (${e.status}).',
        tone: MfToastTone.error,
      );
      return;
    } on ServerUnreachable {
      if (!mounted) return;
      showMfToast(
        context,
        'Server unreachable — try again on your home network.',
        tone: MfToastTone.error,
      );
      return;
    }
    if (!mounted) return;
    if (_minted?.name == name) {
      // The revoked token is the one on screen — retire the code.
      setState(() {
        _minted = null;
        _showToken = false;
      });
    }
    showMfToast(context, 'Revoked.');
    _refreshDevices();
  }

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    final config = AppConfigScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _BackButton(onBack: widget.onBack),
              ),
              const SizedBox(height: 8),
              Text(
                'Settings',
                style: MfType.serif2xl.copyWith(color: mf.text1),
              ),
              const SizedBox(height: 18),

              _sideLabel(mf, 'Connection'),
              _card(
                mf,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MfTextField(
                      label: 'Server address',
                      controller: _serverController,
                      message: 'e.g. 192.168.x.x:8484',
                    ),
                    const SizedBox(height: 14),
                    MfTextField(
                      label: 'Device token',
                      controller: _tokenController,
                      mono: true,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MfButton(label: 'Save', onPressed: _save),
                    ),
                  ],
                ),
              ),

              if (config.isConfigured &&
                  config.client != null &&
                  !_devicesDenied) ...[
                _sideLabel(mf, 'Pair a device'),
                _pairCard(mf, config),
                _sideLabel(mf, 'Paired devices'),
                _devicesCard(mf),
              ],

              _sideLabel(mf, 'Server'),
              _card(
                mf,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.isConfigured
                                ? config.serverHost
                                : 'not configured yet',
                            style: MfType.base.copyWith(
                              fontWeight: FontWeight.w600,
                              color: mf.text1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cleaning, OCR, extraction and search run here '
                            '— never anywhere else.',
                            style: MfType.sm.copyWith(color: mf.text2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    MfPrivacyMark(
                      tone: config.isConfigured
                          ? MfPrivacyTone.ok
                          : MfPrivacyTone.neutral,
                    ),
                  ],
                ),
              ),

              _sideLabel(mf, 'Preferences'),
              _card(
                mf,
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 220,
                      child: MfSelect(
                        label: 'Appearance',
                        options: const ['Light', 'Dark', 'System'],
                        value: switch (config.themeMode) {
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                          ThemeMode.system => 'System',
                        },
                        onChanged: (v) => config.setThemeMode(switch (v) {
                          'Light' => ThemeMode.light,
                          'Dark' => ThemeMode.dark,
                          _ => ThemeMode.system,
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: MfSelect(
                        label: 'Language',
                        options: const ['English', 'Nederlands', 'Deutsch'],
                        // UI copy is English-only in v1: the select renders
                        // per the kit, but picking another language only
                        // explains itself and stays on English.
                        value: 'English',
                        onChanged: (v) {
                          if (v != null && v != 'English') {
                            showMfToast(
                              context,
                              'Language support arrives later.',
                              tone: MfToastTone.info,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideLabel(MfColors mf, String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: MfType.monoCaps.copyWith(color: mf.text3),
    ),
  );

  Widget _card(
    MfColors mf, {
    required EdgeInsets padding,
    required Widget child,
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: mf.surfaceCard,
      border: Border.all(color: mf.border),
      borderRadius: BorderRadius.circular(MfRadius.lg),
    ),
    child: child,
  );

  // ── Pair a device ──────────────────────────────────────────

  Widget _pairCard(MfColors mf, AppConfig config) => _card(
    mf,
    padding: const EdgeInsets.all(20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _qrArea(mf, config),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan with your phone',
                style: MfType.md.copyWith(
                  fontWeight: FontWeight.w600,
                  color: mf.text1,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  'Open Briefkist on the phone and scan this code. Each '
                  'device gets its own token; revoke it here any time. The '
                  'code only works on your home network.',
                  style: MfType.sm.copyWith(color: mf.text2),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: MfTextField(
                  label: 'Device name',
                  controller: _deviceNameController,
                  error: _deviceNameError != null,
                  message: _deviceNameError,
                  onChanged: (_) {
                    if (_deviceNameError != null) {
                      setState(() => _deviceNameError = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MfButton(
                    variant: MfButtonVariant.secondary,
                    size: MfButtonSize.sm,
                    label: 'Create pairing code',
                    onPressed: _minting ? null : _mint,
                  ),
                  if (_minted != null)
                    MfButton(
                      variant: MfButtonVariant.secondary,
                      size: MfButtonSize.sm,
                      label: _showToken
                          ? 'Show code instead'
                          : 'Show token instead',
                      onPressed: () => setState(() => _showToken = !_showToken),
                    ),
                  const MfPrivacyMark(),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// The 150px pairing area: a quiet hatched placeholder until a code is
  /// minted, then the QR (or, toggled, the raw token — visible exactly once;
  /// the server never returns it again).
  Widget _qrArea(MfColors mf, AppConfig config) {
    final minted = _minted;
    if (minted == null) {
      return Container(
        width: 150,
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MfRadius.md),
          border: Border.all(color: mf.borderStrong),
        ),
        child: CustomPaint(
          painter: _HatchPainter(base: mf.surfaceCard, stripe: mf.surfaceInset),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: mf.surfaceCard,
                borderRadius: BorderRadius.circular(MfRadius.sm),
              ),
              child: Text(
                'no active code',
                style: MfType.monoXs.copyWith(color: mf.text3),
              ),
            ),
          ),
        ),
      );
    }
    if (_showToken) {
      return Container(
        width: 150,
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: mf.surfaceInset,
          borderRadius: BorderRadius.circular(MfRadius.md),
          border: Border.all(color: mf.borderStrong),
        ),
        child: SelectableText(
          minted.token,
          style: MfType.monoXs.copyWith(color: mf.text1),
        ),
      );
    }
    // Black-on-white regardless of theme — scanners need the contrast.
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MfRadius.md),
        border: Border.all(color: mf.borderStrong),
      ),
      child: QrImageView(
        data: pairingPayload(serverUrl: config.serverUrl, token: minted.token),
        padding: const EdgeInsets.all(8),
        backgroundColor: Colors.white,
        semanticsLabel: 'Pairing QR code for ${minted.name}',
      ),
    );
  }

  // ── Paired devices ─────────────────────────────────────────

  Widget _devicesCard(MfColors mf) {
    final devices = _devices;
    final Widget child;
    if (_devicesOffline) {
      // Offline: keep the section, say why the list is missing — quietly.
      child = const Padding(
        padding: EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        child: MfPrivacyMark(
          tone: MfPrivacyTone.warn,
          label: 'server unreachable — devices unavailable',
        ),
      );
    } else if (devices == null) {
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        child: Text(
          'Loading devices…',
          style: MfType.sm.copyWith(color: mf.text3),
        ),
      );
    } else if (devices.isEmpty) {
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        child: Text(
          'No devices paired yet.',
          style: MfType.sm.copyWith(color: mf.text2),
        ),
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < devices.length; i++)
            _deviceRow(mf, devices[i], first: i == 0),
        ],
      );
    }
    return _card(mf, padding: EdgeInsets.zero, child: child);
  }

  Widget _deviceRow(MfColors mf, PairedDevice device, {required bool first}) {
    final isThisDevice = _thisDevice != null && device.name == _thisDevice;
    final when = device.created == null
        ? 'paired earlier'
        : 'paired ${formatDate(device.created)}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: mf.border)),
            ),
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
          Text(when, style: MfType.monoXs.copyWith(color: mf.text3)),
          const SizedBox(width: 12),
          if (isThisDevice)
            Text('this device', style: MfType.sm.copyWith(color: mf.text3))
          else
            MfButton(
              variant: MfButtonVariant.destructive,
              size: MfButtonSize.sm,
              label: 'Revoke',
              onPressed: () => _revoke(device.name),
            ),
        ],
      ),
    );
  }
}

/// The kit's QR placeholder hatch: repeating -45° stripes, 6px card /
/// 1px inset (kit.desktop.jsx SettingsContent).
class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.base, required this.stripe});

  final Color base;
  final Color stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = 1;
    for (var d = -size.height; d < size.width; d += 7) {
      canvas.drawLine(
        Offset(d, size.height),
        Offset(d + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.stripe != stripe;
}

/// Ghost '← Archive' back button, matching the kit's settings header.
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
