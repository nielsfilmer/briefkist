// my-flopy — private, local-first snail-mail archive (iOS + macOS client).
// Adaptive shell: phone gets the tab-bar layout (design/ui_kits/mobile),
// desktop gets the topbar + sidebar layout (design/ui_kits/desktop).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'design/mf_theme.dart';
import 'desktop/desktop_shell.dart';
import 'mobile/mobile_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  runApp(MyFlopyApp(config: config));
}

class MyFlopyApp extends StatelessWidget {
  const MyFlopyApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return AppConfigScope(
      config: config,
      child: ListenableBuilder(
        listenable: config,
        builder: (context, _) => MaterialApp(
          title: 'my-flopy',
          debugShowCheckedModeBanner: false,
          theme: mfThemeData(Brightness.light),
          darkTheme: mfThemeData(Brightness.dark),
          themeMode: config.themeMode,
          home: Platform.isMacOS ? const DesktopShell() : const MobileShell(),
        ),
      ),
    );
  }
}
