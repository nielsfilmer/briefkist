// my-flopy — recent-uploads state shared by the mobile capture screen and
// the desktop upload view: newest documents with their processing status,
// polled while anything is still in flight (queued/processing), plus the
// local upload-in-progress entries.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/client.dart';
import 'api/models.dart';

/// A letter the user is uploading right now (before the server assigns an id).
class PendingUpload {
  PendingUpload(this.pageCount);

  final int pageCount;
  bool failed = false;
  String? failureDetail;
}

class UploadsController extends ChangeNotifier {
  UploadsController(this._client) {
    refresh();
  }

  FlopyClient _client;
  Timer? _poll;
  int _generation = 0;
  bool _disposed = false;

  /// Newest documents first (the server's no-query order).
  List<DocumentSummary> recent = const [];

  /// Uploads still in the HTTP phase (or failed there), newest first.
  final List<PendingUpload> pending = [];

  bool offline = false;

  set client(FlopyClient client) {
    _client = client;
    refresh();
  }

  bool get _anythingInFlight =>
      pending.any((u) => !u.failed) ||
      recent.any((d) => d.status == 'queued' || d.status == 'processing');

  /// Upload one document; keeps a pending entry visible until the server
  /// accepts it, then the polled list takes over.
  Future<void> upload(List<String> pagePaths) async {
    final entry = PendingUpload(pagePaths.length);
    pending.insert(0, entry);
    _notify();
    try {
      await _client.uploadDocument(pagePaths);
      pending.remove(entry);
      await refresh();
    } on ServerUnreachable {
      entry.failed = true;
      entry.failureDetail =
          "Can't reach your home server. The photos stay on this device — "
          'try again when you are back on your network.';
      _notify();
      rethrow;
    } on ApiError catch (e) {
      entry.failed = true;
      entry.failureDetail = (e.status == 401 || e.status == 403)
          ? "Your server didn't accept this device's token. Check the "
                'device token in settings.'
          : 'Your server rejected the upload (HTTP ${e.status}).';
      _notify();
      rethrow;
    } catch (_) {
      // Anything escaping the client's taxonomy — Exception OR Error (e.g. a
      // cast failure on a malformed 2xx body) — must still fail the entry,
      // or the row is stuck on "Uploading…" and the poll never stops
      // (review #39 blocking 1 + round-2 nit 3). Rethrown for the caller.
      entry.failed = true;
      entry.failureDetail = 'The upload failed before reaching your server.';
      _notify();
      rethrow;
    }
  }

  /// notifyListeners crashes after dispose; uploads can complete after the
  /// screen is gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void dismissFailed(PendingUpload entry) {
    pending.remove(entry);
    notifyListeners();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    try {
      final docs = await _client.listDocuments(limit: 10, semantic: false);
      if (_disposed || generation != _generation) return;
      recent = docs;
      offline = false;
    } on Exception {
      if (_disposed || generation != _generation) return;
      offline = true;
    }
    notifyListeners();
    _schedulePoll();
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (!_anythingInFlight || _disposed) return;
    // The pipeline takes ~20s/page (issue #13); 3s keeps status fresh
    // without hammering the server.
    _poll = Timer(const Duration(seconds: 3), refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
