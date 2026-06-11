import 'package:dio/dio.dart';
import 'package:moneynote/data/ai_models.dart';

class AiClient {
  final Dio _dio;
  final String baseUrl;
  final String deviceToken;
  AiClient(this._dio, {required this.baseUrl, required this.deviceToken});

  /// Parses [req] on the server. Retries once on transient failures
  /// (network/5xx); 429 is surfaced immediately as `rate_limited`.
  /// Always throws [AiException] on failure — never a raw Dio/cast error.
  Future<ParseResult> parse(ParseRequest req) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final resp = await _dio.post(
          '$baseUrl/ai/parse',
          data: req.toJson(),
          options: Options(
            headers: {'X-Device-Token': deviceToken},
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        final data = resp.data;
        if (data is! Map<String, dynamic>) {
          throw AiException('ai_unavailable');
        }
        return ParseResult.fromJson(data);
      } on AiException {
        rethrow;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 429) throw AiException('rate_limited');
        if (attempt == 0) continue; // retry once (spec §9)
        throw AiException('ai_unavailable');
      }
    }
  }
}
