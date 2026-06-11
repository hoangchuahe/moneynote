import 'package:moneynote/core/prefs.dart';

class ParseRequest {
  final String text;
  final String today; // ISO yyyy-MM-dd
  final Tone tone;
  final List<String> categories;
  final List<String> wallets;
  const ParseRequest({
    required this.text,
    required this.today,
    required this.tone,
    required this.categories,
    required this.wallets,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'today': today,
        'tone': tone.name,
        'categories': categories,
        'wallets': wallets,
      };
}

class ParseResult {
  final int amount;
  final String type; // income | expense
  final String? category;
  final String? merchant;
  final String occurredAt;
  final String note;
  final double confidence;
  final String comment;
  const ParseResult({
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.occurredAt,
    required this.note,
    required this.confidence,
    required this.comment,
  });

  factory ParseResult.fromJson(Map<String, dynamic> j) => ParseResult(
        amount: (j['amount'] as num).toInt(),
        type: j['type'] as String? ?? 'expense',
        category: (j['category'] as String?)?.isEmpty ?? true
            ? null
            : j['category'] as String,
        merchant: j['merchant'] as String?,
        occurredAt: j['occurred_at'] as String,
        note: j['note'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        comment: j['comment'] as String? ?? '',
      );
}

class AiException implements Exception {
  final String code;
  AiException(this.code);
  @override
  String toString() => 'AiException($code)';
}
