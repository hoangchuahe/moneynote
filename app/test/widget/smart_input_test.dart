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
  final ParseResult result;
  _FakeAiClient(
      {this.result = const ParseResult(
          amount: 50000, type: 'expense', category: 'Ăn uống', merchant: null,
          occurredAt: '2026-06-11', note: 'ăn phở', confidence: 0.9, comment: 'ok')})
      : super(Dio(), baseUrl: 'x', deviceToken: 't');
  @override
  Future<ParseResult> parse(ParseRequest req) async => result;
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

    // Poll deterministically: pump until the amount field is pre-filled or
    // timeout. avoids a fixed wall-clock delay that is slow + flaky on CI.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (tester.any(find.text('50.000')) == false) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Timed out waiting for smart-parse result');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump();

    expect(find.text('50.000'), findsOneWidget); // amount field pre-filled, grouped
    expect(find.byKey(const Key('aiCommentCard')), findsOneWidget);
    expect(find.text('ok'), findsOneWidget); // comment hiện trong card
    expect(find.byType(SnackBar), findsNothing); // không còn SnackBar comment

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('amount 0 from AI leaves the amount field empty (no "0")',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final prefs = await AppPrefs.load();

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        prefsProvider.overrideWith((ref) async => prefs),
        aiClientProvider.overrideWithValue(_FakeAiClient(
            result: const ParseResult(
                amount: 0, type: 'expense', category: null, merchant: null,
                occurredAt: '', note: 'mua gì đó', confidence: 0.2,
                comment: ''))),
      ],
      child: const MaterialApp(home: AddTransactionScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byKey(const Key('smartInput')), 'mua gì đó');
    await tester.tap(find.byKey(const Key('parseButton')));
    await tester.pump(); // start _runSmartParse Future

    // Poll deterministically: pump until the parse button re-shows "Phân tích"
    // (meaning _parsing returned to false). Amount 0 leaves the field empty so
    // we can't poll on a positive text match in the form.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!tester.any(find.text('Phân tích'))) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Timed out waiting for smart-parse to finish');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump();

    final amountField = tester.widget<TextField>(find.byKey(const Key('amountField')));
    expect(amountField.controller!.text, isEmpty,
        reason: 'spec §9: field AI không parse được phải để trống, không điền 0');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
