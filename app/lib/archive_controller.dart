// my-flopy — shared archive browse/search state for the mobile and desktop
// layouts: filters, debounced querying, and the four content states of the
// design (populated / loading / empty / offline, plus no-matches).

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/client.dart';
import 'api/models.dart';

enum ArchiveState { loading, populated, empty, offline, noMatches }

class ArchiveController extends ChangeNotifier {
  ArchiveController(this._client) {
    refresh();
  }

  FlopyClient _client;
  Timer? _debounce;
  int _generation = 0;

  List<DocumentSummary> docs = const [];
  ArchiveState state = ArchiveState.loading;

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
      state = result.isNotEmpty
          ? ArchiveState.populated
          : hasFilters
          ? ArchiveState.noMatches
          : ArchiveState.empty;
    } on ServerUnreachable {
      if (generation != _generation) return;
      docs = const [];
      state = ArchiveState.offline;
    } on ApiError {
      if (generation != _generation) return;
      docs = const [];
      state = ArchiveState.offline;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
