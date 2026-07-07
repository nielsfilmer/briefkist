// UploadsController: the error taxonomy must always resolve a pending entry
// (review #39 blocking 1) and polling must stop when nothing is in flight.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:briefkist/api/client.dart';
import 'package:briefkist/uploads_controller.dart';

FlopyClient _client(MockClientHandler handler) =>
    FlopyClient(baseUrl: 'http://test.invalid', inner: MockClient(handler));

void main() {
  test('upload success removes the pending entry', () async {
    final client = _client((req) async {
      if (req.method == 'POST') {
        return http.Response(jsonEncode({'id': 1, 'status': 'queued'}), 202);
      }
      return http.Response(jsonEncode([]), 200);
    });
    final uploads = UploadsController(client);
    // A path that exists: use this test file itself as a fake page.
    await uploads.upload(['test/uploads_controller_test.dart']);
    expect(uploads.pending, isEmpty);
    uploads.dispose();
  });

  test('unreadable page file fails the entry (taxonomy catch-all)', () async {
    final uploads = UploadsController(
      _client((req) async => http.Response(jsonEncode([]), 200)),
    );
    await expectLater(
      uploads.upload(['/nonexistent/page.jpg']),
      throwsA(isA<Exception>()),
    );
    expect(uploads.pending, hasLength(1));
    expect(uploads.pending.first.failed, isTrue);
    expect(uploads.pending.first.failureDetail, isNotNull);
    uploads.dismissFailed(uploads.pending.first);
    expect(uploads.pending, isEmpty);
    uploads.dispose();
  });

  test('401 fails the entry with the token hint', () async {
    final uploads = UploadsController(
      _client((req) async {
        if (req.method == 'POST') return http.Response('nope', 401);
        return http.Response(jsonEncode([]), 200);
      }),
    );
    await expectLater(
      uploads.upload(['test/uploads_controller_test.dart']),
      throwsA(isA<ApiError>()),
    );
    expect(uploads.pending.first.failed, isTrue);
    expect(uploads.pending.first.failureDetail, contains('token'));
    uploads.dispose();
  });

  test('poll timer stops once nothing is in flight', () async {
    var calls = 0;
    final uploads = UploadsController(
      _client((req) async {
        calls++;
        return http.Response(
          jsonEncode([
            {'id': 1, 'status': 'done'},
          ]),
          200,
        );
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = calls;
    // Everything is done → no timer armed → no further calls.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(calls, after);
    uploads.dispose();
  });
}
