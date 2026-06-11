import 'package:dio/dio.dart';
import 'package:moneynote/data/ai_models.dart';

class AiClient {
  final Dio _dio;
  final String baseUrl;
  final String deviceToken;
  AiClient(this._dio, {required this.baseUrl, required this.deviceToken});

  Future<ParseResult> parse(ParseRequest req) async {
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
      return ParseResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw AiException(status == 429 ? 'rate_limited' : 'ai_unavailable');
    }
  }
}
