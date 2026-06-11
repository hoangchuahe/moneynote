import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/ai_client.dart';
import 'package:moneynote/data/ai_models.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../drift_setup.dart';

class _FakeAiClient extends AiClient {
  _FakeAiClient() : super(Dio(), baseUrl: 'x', deviceToken: 't');
  @override
  Future<ParseResult> parse(ParseRequest req) async => const ParseResult(
        amount: 50000, type: 'expense', category: 'Ăn uống', merchant: null,
        occurredAt: '2026-06-11', note: 'ăn phở', confidence: 0.9, comment: 'ok');
}

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('smart input parses and pre-fills the form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final prefs = await AppPrefs.load();

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Use an already-resolved value for prefsProvider so .valueOrNull is
    // non-null immediately when _runSmartParse reads it.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        prefsProvider.overrideWith((ref) async => prefs),
        aiClientProvider.overrideWithValue(_FakeAiClient()),
      ],
      child: const MaterialApp(home: AddTransactionScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byKey(const Key('smartInput')), 'ăn phở 50k');
    await tester.tap(find.byKey(const Key('parseButton')));
    await tester.pump(); // start _runSmartParse Future

    // Allow the async chain (await prefs future + fake parse + Drift
    // lookupMerchant) to complete in real wall-clock time.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('50000'), findsOneWidget); // amount field pre-filled

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
