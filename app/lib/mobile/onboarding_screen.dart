// my-flopy — onboarding. Source: design/ui_kits/mobile/kit.mobile.jsx

import 'package:flutter/material.dart';

import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_mark.dart';
import '../design/widgets/mf_privacy_mark.dart';

/// The three-step first-run walkthrough shown on the capture/archive tabs
/// while no server is configured: promise → pairing → first letter.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onPair,
    required this.onDone,
  });

  /// Jump to settings to enter the server address / device token. The kit's
  /// step-2 CTA is "Scan the code"; QR pairing lands in the pairing PR
  /// (tracker #29), so until then both the CTA and the alt link route here.
  final VoidCallback onPair;

  /// Finished (or skipped past) the walkthrough — go capture.
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final mf = context.mf;
    // Kit copy, verbatim (only the pairing CTA differs — see [onPair]).
    final (art, title, body, cta, VoidCallback onCta) = switch (_step) {
      0 => (
        MfMark(size: 64, color: mf.accent),
        'Your mail stays home.',
        'my-flopy turns paper letters into a searchable archive — processed '
            'entirely on your own server. No cloud, no telemetry. Nothing '
            'ever leaves hardware you own.',
        'Continue',
        () => setState(() => _step = 1),
      ),
      1 => (
        MfIcon(MfGlyphs.qr, size: 56, color: mf.accent),
        'Pair with your server.',
        'Open my-flopy on the computer that runs your archive and scan the '
            'code it shows. This phone will talk only to your own server.',
        'Set the server address',
        widget.onPair,
      ),
      _ => (
        MfIcon(MfGlyphs.camera, size: 56, color: mf.accent),
        'File your first letter.',
        'Photograph each page. Your server cleans the image, reads it, and '
            'files it — usually within a minute.',
        'Open the camera',
        widget.onDone,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                art,
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: MfType.serif2xl.copyWith(color: mf.text1),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: MfType.md.copyWith(color: mf.text2),
                  ),
                ),
                if (_step == 0) ...[
                  const SizedBox(height: 18),
                  const MfPrivacyMark(),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _step ? mf.accent : mf.borderStrong,
                    ),
                  ),
                ],
              ],
            ),
          ),
          MfButton(
            size: MfButtonSize.lg,
            fullWidth: true,
            label: cta,
            onPressed: onCta,
          ),
          if (_step == 1)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(
                child: Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onPair,
                    child: Text(
                      'or paste a device token',
                      style: MfType.base.copyWith(color: mf.textLink),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
