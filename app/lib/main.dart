// my-flopy — private, local-first snail-mail archive (iOS + macOS client).
// Currently boots the design-system gallery; the app shell replaces it in the
// next PR (archive/search/detail).

import 'package:flutter/material.dart';

import 'design/mf_theme.dart';
import 'dev/gallery.dart';

void main() => runApp(const MyFlopyApp());

class MyFlopyApp extends StatefulWidget {
  const MyFlopyApp({super.key});

  @override
  State<MyFlopyApp> createState() => _MyFlopyAppState();
}

class _MyFlopyAppState extends State<MyFlopyApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'my-flopy',
      debugShowCheckedModeBanner: false,
      theme: mfThemeData(Brightness.light),
      darkTheme: mfThemeData(Brightness.dark),
      themeMode: _mode,
      home: Builder(
        builder: (context) => GalleryScreen(
          dark: Theme.of(context).brightness == Brightness.dark,
          onToggleDark: () => setState(() {
            _mode = Theme.of(context).brightness == Brightness.dark
                ? ThemeMode.light
                : ThemeMode.dark;
          }),
        ),
      ),
    );
  }
}
