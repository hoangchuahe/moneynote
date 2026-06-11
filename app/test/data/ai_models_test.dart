import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/ai_models.dart';

void main() {
  test('fromJson maps a full payload', () {
    final r = ParseResult.fromJson(const {
      'amount': 50000,
      'type': 'expense',
      'category': 'Ăn uống',
      'merchant': 'highlands',
      'occurred_at': '2026-06-11',
      'note': 'cà phê',
      'confidence': 0.9,
      'comment': 'ok',
    });
    expect(r.amount, 50000);
    expect(r.merchant, 'highlands');
    expect(r.occurredAt, '2026-06-11');
  });

  test('fromJson tolerates missing/null fields instead of throwing', () {
    // A degraded server response must not crash the app (spec §9: pre-fill
    // what parsed, leave the rest empty).
    final r = ParseResult.fromJson(const {'type': 'expense'});
    expect(r.amount, 0);
    expect(r.category, isNull);
    expect(r.merchant, isNull);
    expect(r.occurredAt, '');
    expect(r.note, '');
    expect(r.confidence, 0);
    expect(r.comment, '');
  });
}
