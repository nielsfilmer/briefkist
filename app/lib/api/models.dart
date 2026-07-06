// my-flopy — API models, mirroring the FastAPI backend's JSON
// (server/store.py projections). Keep field names in sync with the server.

import 'dart:convert';

/// List-projection of a document (GET /api/documents).
class DocumentSummary {
  const DocumentSummary({
    required this.id,
    this.title,
    this.correspondent,
    this.correspondentPlace,
    this.category,
    this.documentDate,
    this.reference,
    this.language,
    this.summary,
    this.keywords = const [],
    required this.status,
    this.createdAt,
    this.pageCount = 1,
  });

  final int id;
  final String? title;
  final String? correspondent;
  final String? correspondentPlace;
  final String? category;

  /// ISO date (YYYY-MM-DD) or null when not detected.
  final String? documentDate;
  final String? reference;
  final String? language;
  final String? summary;
  final List<String> keywords;

  /// queued | processing | done | failed (server vocabulary).
  final String status;
  final String? createdAt;
  final int pageCount;

  factory DocumentSummary.fromJson(Map<String, dynamic> json) =>
      DocumentSummary(
        id: json['id'] as int,
        title: json['title'] as String?,
        correspondent: json['correspondent'] as String?,
        correspondentPlace: json['correspondent_place'] as String?,
        category: json['category'] as String?,
        documentDate: json['document_date'] as String?,
        reference: json['reference'] as String?,
        language: json['language'] as String?,
        summary: json['summary'] as String?,
        keywords: [...?(json['keywords'] as List?)?.cast<String>()],
        status: json['status'] as String? ?? 'done',
        createdAt: json['created_at'] as String?,
        pageCount: json['page_count'] as int? ?? 1,
      );
}

/// A page of a document (inside GET /api/documents/{id}).
class PageInfo {
  const PageInfo({required this.pageNo, this.ocrConfidence, this.ocrEngine});

  final int pageNo;
  final double? ocrConfidence;
  final String? ocrEngine;

  factory PageInfo.fromJson(Map<String, dynamic> json) => PageInfo(
    pageNo: json['page_no'] as int,
    ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble(),
    ocrEngine: json['ocr_engine'] as String?,
  );
}

/// A format-critical extracted field with its verification state.
class ExtractedField {
  const ExtractedField({required this.key, this.valid, this.verified = false});

  final String key;
  final bool? valid;
  final bool verified;

  factory ExtractedField.fromJson(Map<String, dynamic> json) => ExtractedField(
    key: json['key'] as String,
    valid: switch (json['valid']) {
      null => null,
      final bool b => b,
      final num n => n != 0,
      _ => null,
    },
    verified: switch (json['verified']) {
      final bool b => b,
      final num n => n != 0,
      _ => false,
    },
  );
}

/// Full document (GET /api/documents/{id}).
class DocumentDetail {
  const DocumentDetail({
    required this.summary,
    this.subject,
    this.recipient,
    this.pages = const [],
    this.fields = const [],
  });

  final DocumentSummary summary;
  final String? subject;
  final String? recipient;
  final List<PageInfo> pages;
  final List<ExtractedField> fields;

  factory DocumentDetail.fromJson(Map<String, dynamic> json) => DocumentDetail(
    summary: DocumentSummary.fromJson(json),
    subject: json['subject'] as String?,
    recipient: json['recipient'] as String?,
    pages: [
      for (final p in (json['pages'] as List? ?? []))
        PageInfo.fromJson(p as Map<String, dynamic>),
    ],
    fields: [
      for (final f in (json['fields'] as List? ?? []))
        ExtractedField.fromJson(f as Map<String, dynamic>),
    ],
  );

  /// Whether the user has verified/corrected [field] (corrected tick).
  bool isVerified(String field) =>
      fields.any((f) => f.key == field && f.verified);
}

/// A correspondent with its document count (GET /api/correspondents).
class Correspondent {
  const Correspondent({required this.name, required this.count});

  final String name;
  final int count;

  factory Correspondent.fromJson(Map<String, dynamic> json) =>
      Correspondent(name: json['name'] as String, count: json['count'] as int);
}

/// The closed category list (plan.md v0.4 #12 / design readme).
const kCategories = [
  'government',
  'medical',
  'insurance',
  'bank',
  'utility',
  'telecom',
  'legal',
  'employment',
  'education',
  'housing',
  'commercial',
  'membership',
  'personal',
  'other',
];

/// "12 Mar 2026" — the design's date rule: absolute, unambiguous, never 3/12.
String formatDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// "just now" / "N min ago" / "N h ago" / "12 Mar 2026". The server sends
/// created_at as ISO UTC (Z-suffixed); zone-less 'YYYY-MM-DD HH:MM:SS'
/// values are pinned to UTC too.
String relativeTime(String? createdAt) {
  if (createdAt == null || createdAt.isEmpty) return '';
  var text = createdAt.replaceFirst(' ', 'T');
  if (!text.endsWith('Z') && !text.contains('+')) text = '${text}Z';
  final utc = DateTime.tryParse(text);
  if (utc == null) return '';
  final local = utc.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inSeconds < 60) return 'just now'; // covers small clock skew too
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return formatDate(local.toIso8601String());
}

/// A paired device (GET /api/devices) — tokens are never listed.
class PairedDevice {
  const PairedDevice({required this.name, this.created});

  final String name;

  /// ISO date the device was paired, or null for pre-pairing tokens.
  final String? created;

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
    name: json['name'] as String,
    created: json['created'] as String?,
  );
}

/// A freshly minted device (POST /api/devices) — the only time the token
/// is ever visible.
class MintedDevice {
  const MintedDevice({required this.name, required this.token, this.created});

  final String name;
  final String token;
  final String? created;

  factory MintedDevice.fromJson(Map<String, dynamic> json) => MintedDevice(
    name: json['name'] as String,
    token: json['token'] as String,
    created: json['created'] as String?,
  );
}

/// The QR payload for pairing: what the phone scans from the desktop
/// settings screen. JSON: {"flopy": 1, "url": ..., "token": ...} — the
/// version key lets a future format evolve without breaking old scanners.
String pairingPayload({required String serverUrl, required String token}) =>
    '{"flopy":1,"url":${_jsonString(serverUrl)},"token":${_jsonString(token)}}';

/// Parse a scanned pairing QR; returns (url, token) or null when it isn't
/// a my-flopy pairing code.
(String, String)? parsePairingPayload(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['flopy'] != 1) return null;
    final url = decoded['url'];
    final token = decoded['token'];
    if (url is! String || token is! String || url.isEmpty || token.isEmpty) {
      return null;
    }
    return (url, token);
  } on FormatException {
    return null;
  }
}

String _jsonString(String value) => jsonEncode(value);
