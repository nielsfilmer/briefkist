// my-flopy — QR pairing scanner. Source: design/ui_kits/mobile/kit.mobile.jsx
// (OnboardingScreen step 2 "Scan the code" flow).
//
// Full-screen pushed route over the live camera. Every detected barcode is
// run through [parsePairingPayload]; the first valid my-flopy payload stops
// the camera and pops with [ScanPairingScanned]. The route's popped value is
// a [ScanPairingResult]? — null means the user simply closed the scanner.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/models.dart';
import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_icon_button.dart';
import '../design/widgets/mf_privacy_mark.dart';

/// What the scan route resolved to (the route pops with `ScanPairingResult?`;
/// null = closed without a result).
sealed class ScanPairingResult {
  const ScanPairingResult();
}

/// A valid pairing code was scanned — connect to this server.
class ScanPairingScanned extends ScanPairingResult {
  const ScanPairingScanned({required this.serverUrl, required this.token});

  final String serverUrl;
  final String token;
}

/// The user chose 'Paste a token instead' — open manual token entry.
class ScanPairingPasteFallback extends ScanPairingResult {
  const ScanPairingPasteFallback();
}

/// Full-screen QR scanner for the pairing code shown by the desktop app.
class ScanPairingScreen extends StatefulWidget {
  const ScanPairingScreen({super.key});

  @override
  State<ScanPairingScreen> createState() => _ScanPairingScreenState();
}

class _ScanPairingScreenState extends State<ScanPairingScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // We own the controller, so MobileScanner's built-in lifecycle handling
    // (useAppLifecycleState) does not apply — pause/resume it ourselves.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized || _controller.value.error != null) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_handled) unawaited(_controller.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  void _onDetect(BarcodeCapture capture) {
    // isCurrent: a system back-gesture pops without going through _close(),
    // so a barcode landing during that transition must not pop again.
    if (_handled || ModalRoute.of(context)?.isCurrent != true) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final parsed = parsePairingPayload(raw);
      if (parsed == null) continue; // not a my-flopy code — keep scanning
      _handled = true;
      unawaited(_controller.stop());
      final (url, token) = parsed;
      Navigator.of(
        context,
      ).pop(ScanPairingScanned(serverUrl: url, token: token));
      return;
    }
  }

  void _pasteFallback() {
    if (_handled) return;
    _handled = true;
    unawaited(_controller.stop()); // no-op when the camera never started
    Navigator.of(context).pop(const ScanPairingPasteFallback());
  }

  void _close() {
    if (_handled) return;
    // Claim the pop before it happens: a barcode detected during the pop
    // transition must not trigger a second pop from _onDetect.
    _handled = true;
    unawaited(_controller.stop());
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mf.surfacePage,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Camera-permission failure and camera-less hardware both land
            // here. The iOS simulator has no camera, so THIS is the path the
            // simulator always shows — the screen must degrade to it.
            errorBuilder: _cameraUnavailable,
          ),
          // Chrome. Over the live preview the app theme is meaningless (the
          // feed isn't themed), so the bars force the dark palette + scrim —
          // legible in both app themes (deliberate deviation from the kit's
          // themed chrome). Over the error state the page is a themed
          // surface, so the chrome follows the app theme.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) => state.error != null
                ? SafeArea(
                    child: Column(
                      children: [_topBar(context.mf, barBackground: false)],
                    ),
                  )
                : Theme(
                    data: mfThemeData(Brightness.dark),
                    child: SafeArea(
                      child: Column(
                        children: [
                          _topBar(mfDark, barBackground: true),
                          const Spacer(),
                          _bottomBar(mfDark),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Scrim-style top bar: close + serif-lg title. Over the error empty state
  /// the scrim is dropped and the theme's ink is used instead.
  Widget _topBar(MfColors mf, {required bool barBackground}) {
    return Container(
      color: barBackground ? mf.scrim : null,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      child: Row(
        children: [
          MfIconButton(
            label: 'Close',
            size: MfIconButtonSize.lg,
            onPressed: _close,
            child: MfIcon(
              MfGlyphs.x,
              size: 18,
              strokeWidth: 2,
              color: mf.text1,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Scan the pairing code',
              style: MfType.serifLg.copyWith(color: mf.text1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(MfColors mf) {
    return Container(
      width: double.infinity,
      color: mf.scrim,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MfPrivacyMark(
            label: 'this phone will talk only to your own server',
          ),
          const SizedBox(height: 8),
          MfButton(
            variant: MfButtonVariant.ghost,
            label: 'Paste a token instead',
            onPressed: _pasteFallback,
          ),
        ],
      ),
    );
  }

  /// MobileScanner errorBuilder body: honest empty state on the themed page
  /// surface, with the paste fallback as the action.
  Widget _cameraUnavailable(BuildContext context, MobileScannerException e) {
    final mf = context.mf;
    return ColoredBox(
      color: mf.surfacePage,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: MfEmptyState(
              icon: MfIcon(MfGlyphs.camera, size: 40, color: mf.text3),
              title: 'Camera unavailable',
              body: e.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'my-flopy has no camera permission. Allow the camera in '
                        'the system settings, or paste the token instead.'
                  : 'No usable camera on this device. Paste the token '
                        'instead.',
              action: MfButton(
                label: 'Paste a token instead',
                onPressed: _pasteFallback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
