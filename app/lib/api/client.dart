// my-flopy — HTTP client for the self-hosted backend. The ONLY network
// surface in the app, and it talks exclusively to the owner's server
// (plan.md §5.1): base URL comes from user configuration, never a default
// public host.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// The server can't be reached (off the home network / VPN down).
class ServerUnreachable implements Exception {
  const ServerUnreachable(this.cause);

  final Object cause;

  @override
  String toString() => 'ServerUnreachable($cause)';
}

/// Non-2xx response.
class ApiError implements Exception {
  const ApiError(this.status, this.detail);

  final int status;
  final String detail;

  @override
  String toString() => 'ApiError($status): $detail';
}

class FlopyClient {
  FlopyClient({required this.baseUrl, this.token, http.Client? inner})
    : _http = inner ?? http.Client();

  /// e.g. `http://127.0.0.1:8484` — normalized without a trailing slash.
  final String baseUrl;
  final String? token;
  final http.Client _http;

  Map<String, String> get authHeaders => {
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String>? params]) => Uri.parse(
    '$baseUrl$path',
  ).replace(queryParameters: (params?.isNotEmpty ?? false) ? params : null);

  Future<dynamic> _getJson(String path, [Map<String, String>? params]) async {
    final http.Response resp;
    try {
      resp = await _http
          .get(_uri(path, params), headers: authHeaders)
          .timeout(const Duration(seconds: 10));
    } on Exception catch (e) {
      throw ServerUnreachable(e);
    }
    if (resp.statusCode ~/ 100 != 2) {
      throw ApiError(resp.statusCode, resp.body);
    }
    try {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    } on FormatException catch (e) {
      // A 200 that isn't JSON means something between us and the server
      // answered — captive portal, wrong host — treat as unreachable.
      throw ServerUnreachable(e);
    }
  }

  Future<List<DocumentSummary>> listDocuments({
    String? query,
    bool semantic = true,
    String? category,
    String? status,
    String? correspondent,
    String? dateFrom,
    String? dateTo,
    int limit = 50,
  }) async {
    final json =
        await _getJson('/api/documents', {
              if (query != null && query.isNotEmpty) 'query': query,
              if (!semantic) 'semantic': 'false',
              'category': ?category,
              'status': ?status,
              'correspondent': ?correspondent,
              'date_from': ?dateFrom,
              'date_to': ?dateTo,
              'limit': '$limit',
            })
            as List;
    return [
      for (final d in json) DocumentSummary.fromJson(d as Map<String, dynamic>),
    ];
  }

  Future<DocumentDetail> getDocument(int id) async => DocumentDetail.fromJson(
    await _getJson('/api/documents/$id') as Map<String, dynamic>,
  );

  /// Apply one or more corrections; returns the updated document.
  Future<DocumentDetail> correctDocument(
    int id,
    Map<String, dynamic> patch,
  ) async {
    final http.Response resp;
    try {
      resp = await _http
          .patch(
            _uri('/api/documents/$id'),
            headers: {...authHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode(patch),
          )
          .timeout(const Duration(seconds: 10));
    } on Exception catch (e) {
      throw ServerUnreachable(e);
    }
    if (resp.statusCode ~/ 100 != 2) {
      throw ApiError(resp.statusCode, resp.body);
    }
    final dynamic json;
    try {
      json = jsonDecode(utf8.decode(resp.bodyBytes));
    } on FormatException catch (e) {
      // A 200 that isn't JSON means something between us and the server
      // answered — captive portal, wrong host — treat as unreachable.
      throw ServerUnreachable(e);
    }
    return DocumentDetail.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Correspondent>> listCorrespondents() async {
    final json = await _getJson('/api/correspondents') as List;
    return [
      for (final c in json) Correspondent.fromJson(c as Map<String, dynamic>),
    ];
  }

  /// Queue/document counters (GET /api/status).
  Future<Map<String, dynamic>> status() async =>
      (await _getJson('/api/status')) as Map<String, dynamic>;

  /// Upload one document (all pages, in order) — POST /api/documents.
  /// Returns the new document id; the server queues processing (202).
  Future<int> uploadDocument(List<String> pagePaths) async {
    final req = http.MultipartRequest('POST', _uri('/api/documents'))
      ..headers.addAll(authHeaders);
    for (final path in pagePaths) {
      req.files.add(await http.MultipartFile.fromPath('files', path));
    }
    final http.StreamedResponse streamed;
    try {
      // Generous timeout: a multi-page HEIC upload over WiFi takes a while.
      streamed = await _http.send(req).timeout(const Duration(minutes: 2));
    } on Exception catch (e) {
      throw ServerUnreachable(e);
    }
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode ~/ 100 != 2) {
      throw ApiError(resp.statusCode, resp.body);
    }
    final dynamic json;
    try {
      json = jsonDecode(utf8.decode(resp.bodyBytes));
    } on FormatException catch (e) {
      throw ServerUnreachable(e);
    }
    return (json as Map<String, dynamic>)['id'] as int;
  }

  /// URL of a page image; pass [authHeaders] to Image.network.
  Uri imageUri(int docId, int pageNo, {String kind = 'thumb'}) =>
      _uri('/api/documents/$docId/pages/$pageNo/image', {'kind': kind});

  void close() => _http.close();
}
