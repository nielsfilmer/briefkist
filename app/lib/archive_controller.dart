// my-flopy — shared archive browse/search state for the mobile and desktop
// layouts: filters, debounced querying, and the content states of the design
// (populated / loading / empty / offline / error, plus no-matches).

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/client.dart';
import 'api/models.dart';

enum ArchiveState { loading, populated, empty, offline, noMatches, error }

class ArchiveController extends ChangeNotifier {
  ArchiveController(this._client) {
    refresh();
  }

  FlopyClient _client;
  Timer? _debounce;
  int _generation = 0;

  List<DocumentSummary> docs = const [];
  ArchiveState state = ArchiveState.loading;

  /// Set alongside [ArchiveState.error]; null in every other state.
  String? errorMessage;

  String query = '';
  String? category;
  String? correspondent;
  String? dateFrom;
  String? dateTo;

  bool get hasFilters =>
      query.isNotEmpty ||
      category != null ||
      correspondent != null ||
      dateFrom != null ||
      dateTo != null;

  /// Swap the client after the connection settings change.
  set client(FlopyClient client) {
    _client = client;
    refresh();
  }

  void setQuery(String value) {
    query = value;
    _debounce?.cancel();
    // Search-as-you-type, debounced so the semantic leg isn't hammered.
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
    notifyListeners();
  }

  void setCategory(String? value) {
    category = value;
    refresh();
  }

  void setCorrespondent(String? value) {
    correspondent = value;
    refresh();
  }

  void setDateRange(String? from, String? to) {
    dateFrom = from;
    dateTo = to;
    refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = ArchiveState.loading;
    notifyListeners();
    try {
      final result = await _client.listDocuments(
        query: query.isEmpty ? null : query,
        category: category,
        correspondent: correspondent,
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: 100,
      );
      if (generation != _generation) return; // superseded by a newer request
      docs = result;
      errorMessage = null;
      state = result.isNotEmpty
          ? ArchiveState.populated
          : hasFilters
          ? ArchiveState.noMatches
          : ArchiveState.empty;
    } on ServerUnreachable {
      if (generation != _generation) return;
      docs = const [];
      errorMessage = null;
      state = ArchiveState.offline;
    } on ApiError catch (e) {
      // The server answered but refused: distinct from offline, so the UI
      // can say what happened and what to do next.
      if (generation != _generation) return;
      docs = const [];
      errorMessage = (e.status == 401 || e.status == 403)
          ? "Your server didn't accept this device's token. Check the "
                'device token in settings.'
          : 'Your server returned an error (HTTP ${e.status}).';
      state = ArchiveState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
