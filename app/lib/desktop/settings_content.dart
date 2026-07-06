// my-flopy — desktop settings (connection, server, preferences).
// Source: design/ui_kits/desktop/kit.desktop.jsx

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_select.dart';
import '../design/widgets/mf_text_field.dart';
import '../design/widgets/mf_toast.dart';

/// v1-pragmatic settings: manual connection (server address + device token),
/// the server card, and appearance/language preferences.
///
/// The kit's "Pair a device" QR card and the paired-devices list land in the
/// pairing PR (tracker #29) — they are deliberately not rendered yet.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final config = AppConfigScope.of(context);
    _serverController.text = config.serverUrl;
    _tokenController.text = config.token;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _tokenController.dispose();
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

  /// Host part of the configured server URL for the server card.
  static String _host(String url) {
    var u = url.trim();
    if (u.isEmpty) return 'not configured yet';
    if (!u.contains('://')) u = 'http://$u';
    final host = Uri.tryParse(u)?.host ?? '';
    return host.isEmpty ? url.trim() : host;
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
                            _host(config.serverUrl),
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
