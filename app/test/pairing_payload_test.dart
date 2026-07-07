// parsePairingPayload: the scanner runs EVERY detected barcode through this
// parser, so anything that isn't exactly a Briefkist pairing payload must come
// back null (PR #42 — pairing).

import 'package:flutter_test/flutter_test.dart';
import 'package:briefkist/api/models.dart';

void main() {
  test('valid payload round-trips through pairingPayload', () {
    final raw = pairingPayload(
      serverUrl: 'http://192.168.1.20:8484',
      token: 'abc-DEF_123',
    );
    expect(parsePairingPayload(raw), (
      'http://192.168.1.20:8484',
      'abc-DEF_123',
    ));
  });

  test('round-trip survives JSON-significant characters', () {
    final raw = pairingPayload(
      serverUrl: 'http://192.168.1.20:8484/"path"',
      token: 'to\\ken"with\nweird',
    );
    expect(parsePairingPayload(raw), (
      'http://192.168.1.20:8484/"path"',
      'to\\ken"with\nweird',
    ));
  });

  test('malformed JSON is null', () {
    expect(parsePairingPayload('not json at all'), isNull);
    expect(parsePairingPayload('{"flopy":1,"url":'), isNull);
    expect(parsePairingPayload(''), isNull);
  });

  test('non-object JSON is null', () {
    expect(parsePairingPayload('[1]'), isNull);
    expect(parsePairingPayload('"x"'), isNull);
    expect(parsePairingPayload('42'), isNull);
    expect(parsePairingPayload('null'), isNull);
  });

  test('wrong or missing version is null', () {
    expect(
      parsePairingPayload('{"flopy":2,"url":"http://h","token":"t"}'),
      isNull,
    );
    expect(parsePairingPayload('{"url":"http://h","token":"t"}'), isNull);
  });

  test('missing or empty url/token is null', () {
    expect(parsePairingPayload('{"flopy":1,"token":"t"}'), isNull);
    expect(parsePairingPayload('{"flopy":1,"url":"http://h"}'), isNull);
    expect(parsePairingPayload('{"flopy":1,"url":"","token":"t"}'), isNull);
    expect(
      parsePairingPayload('{"flopy":1,"url":"http://h","token":""}'),
      isNull,
    );
    expect(parsePairingPayload('{"flopy":1,"url":7,"token":"t"}'), isNull);
    expect(
      parsePairingPayload('{"flopy":1,"url":"http://h","token":null}'),
      isNull,
    );
  });

  test('extra keys are tolerated', () {
    expect(
      parsePairingPayload(
        '{"flopy":1,"url":"http://h","token":"t","extra":true,"n":2}',
      ),
      ('http://h', 't'),
    );
  });
}
