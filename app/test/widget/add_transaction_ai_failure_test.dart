import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/ai_client.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../drift_setup.dart';

/// Always returns 500 → AiClient retries once then throws AiException.
class _AlwaysFailAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString('{"error":"ai_unavailable"}', 500,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('AI parse failure shows snackbar and manual entry still saves',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final failingClient =
        AiClient(Dio()..httpClientAdapter = _AlwaysFailAdapter(),
            baseUrl: 'http://unreachable', deviceToken: 't1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aiClientProvider.overrideWithValue(failingClient),
        ],
        child: const MaterialApp(home: AddTransactionScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byKey(const Key('smartInput')), 'an pho 50k');
    await tester.tap(find.byKey(const Key('parseButton')));
    await tester.runAsync(() async {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('AI không khả dụng, nhập tay nhé'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amountField')), '50000');
    await tester.tap(find.byKey(const Key('cat_Ăn uống')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pump(const Duration(milliseconds: 200));

    final txns =
        await tester.runAsync(() => AppRepository(db).watchAllTransactions().first);
    expect(txns, hasLength(1));
    expect(txns!.single.amount, 50000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
