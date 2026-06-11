import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/ai_client.dart';
import 'package:moneynote/data/ai_models.dart';

class _StubAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  _StubAdapter(this.status, this.body);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(body, status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}

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
}
