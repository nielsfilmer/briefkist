// my-flopy — connection + appearance configuration, persisted locally with
// shared_preferences. Populated by QR pairing (scan_pairing_screen) or the
// manual server-address + token fields in settings.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/client.dart';

class AppConfig extends ChangeNotifier {
  AppConfig._(this._prefs);

  static Future<AppConfig> load() async =>
      AppConfig._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  FlopyClient? _client;

  String get serverUrl => _prefs.getString('server_url') ?? '';
  String get token => _prefs.getString('device_token') ?? '';

  ThemeMode get themeMode => switch (_prefs.getString('theme_mode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  bool get isConfigured => serverUrl.isNotEmpty;

  /// Host part of the configured server URL, for the connection captions;
  /// empty when no server is configured.
  String get serverHost {
    if (serverUrl.isEmpty) return '';
    final u = Uri.tryParse(_normalize(serverUrl));
    return (u == null || u.host.isEmpty) ? serverUrl : u.host;
  }

  /// The API client for the configured server; rebuilt when config changes.
  FlopyClient? get client {
    if (!isConfigured) return null;
    return _client ??= FlopyClient(
      baseUrl: _normalize(serverUrl),
      token: token.isEmpty ? null : token,
    );
  }

  Future<void> setConnection({
    required String serverUrl,
    required String token,
  }) async {
    await _prefs.setString('server_url', serverUrl.trim());
    await _prefs.setString('device_token', token.trim());
    _client?.close();
    _client = null;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString('theme_mode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  /// Whether [serverUrl]'s host is a loopback address ('127.0.0.1',
  /// 'localhost', '::1') — reachable only from the machine it names. A
  /// pairing code that embeds it could never connect another device
  /// (PR #42 finding 2). Note this needs the URL's HOST specifically
  /// ([serverHost] falls back to the raw URL when it can't parse).
  static bool isLoopbackServerUrl(String serverUrl) {
    final host = Uri.tryParse(_normalize(serverUrl))?.host ?? '';
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  static String _normalize(String url) {
    var u = url.trim();
    if (!u.contains('://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}

/// Inherited access to the single AppConfig instance.
class AppConfigScope extends InheritedNotifier<AppConfig> {
  const AppConfigScope({
    super.key,
    required AppConfig config,
    required super.child,
  }) : super(notifier: config);

  static AppConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppConfigScope>()!.notifier!;
}
