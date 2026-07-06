// my-flopy — settings screen. Source: design/ui_kits/mobile/kit.mobile.jsx

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_chip.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_text_field.dart';
import '../design/widgets/mf_toast.dart';

/// The settings tab: server card, connection fields, appearance.
/// QR pairing and the paired-device list from the kit land in the pairing PR
/// (tracker #29); until then the connection is a plain address + token.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _server = TextEditingController();
  final _token = TextEditingController();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final config = AppConfigScope.of(context);
    _server.text = config.serverUrl;
    _token.text = config.token;
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
    // 76 clears the mobile tab bar (mf_toast.dart guidance).
    showMfToast(context, 'Saved.', bottomOffset: 76);
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
              'my-flopy 1.0 · self-hosted',
              style: MfType.monoXs.copyWith(color: mf.text3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(
    MfColors mf, {
    required EdgeInsets padding,
    required Widget child,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: mf.surfaceCard,
        border: Border.all(color: mf.border),
        borderRadius: BorderRadius.circular(MfRadius.lg),
      ),
      child: child,
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
