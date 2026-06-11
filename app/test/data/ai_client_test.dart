import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/ai_client.dart';
import 'package:moneynote/data/ai_models.dart';

class _StubAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  int calls = 0;
  _StubAdapter(this.status, this.body);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(body, status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}

/// Fails with [failStatus] on the first call, then answers 200 [okBody].
class _FlakyAdapter implements HttpClientAdapter {
  final int failStatus;
  final String okBody;
  int calls = 0;
  _FlakyAdapter(this.failStatus, this.okBody);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (calls == 1) {
      return ResponseBody.fromString('{"error":"ai_unavailable"}', failStatus,
          headers: {Headers.contentTypeHeader: ['application/json']});
    }
    return ResponseBody.fromString(okBody, 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}

const _okBody =
    '{"amount":50000,"type":"expense","category":"Ăn uống","merchant":null,"occurred_at":"2026-06-11","note":"an pho","confidence":0.9,"comment":"ok"}';

ParseRequest _req() => const ParseRequest(
    text: 'an pho 50k', today: '2026-06-11', tone: Tone.serious,
    categories: ['Ăn uống'], wallets: ['Tiền mặt']);

void main() {
  test('maps 200 JSON to ParseResult', () async {
    final dio = Dio()
      ..httpClientAdapter = _StubAdapter(200,
          '{"amount":50000,"type":"expense","category":"Ăn uống","merchant":null,"occurred_at":"2026-06-11","note":"an pho","confidence":0.9,"comment":"ok"}');
    final client = AiClient(dio, baseUrl: 'http://x', deviceToken: 't1');
    final r = await client.parse(_req());
    expect(r.amount, 50000);
    expect(r.category, 'Ăn uống');
    expect(r.merchant, isNull);
  });

  test('throws AiException on 429', () async {
    final dio = Dio()..httpClientAdapter = _StubAdapter(429, '{"error":"rate_limited"}');
    final client = AiClient(dio, baseUrl: 'http://x', deviceToken: 't1');
    expect(() => client.parse(_req()), throwsA(isA<AiException>()));
  });

  test('retries once on a transient failure then succeeds (spec §9)', () async {
    final adapter = _FlakyAdapter(502, _okBody);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = AiClient(dio, baseUrl: 'http://x', deviceToken: 't1');
    final r = await client.parse(_req());
    expect(r.amount, 50000);
    expect(adapter.calls, 2);
  });

  test('throws AiException (not a raw cast error) on a non-JSON 200 body',
      () async {
    final dio = Dio()..httpClientAdapter = _StubAdapter(200, 'oops not json');
    final client = AiClient(dio, baseUrl: 'http://x', deviceToken: 't1');
    expect(() => client.parse(_req()), throwsA(isA<AiException>()));
  });
}
