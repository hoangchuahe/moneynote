import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/features/budgets/budgets_screen.dart';
import 'package:moneynote/state/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];

    return txnsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (txns) {
        final s = summarize(txns, month);
        final recent = txns.take(15).toList();
        return ListView(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tháng ${month.month}/${month.year}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _row(context, 'Thu', s.income, Colors.green),
                    _row(context, 'Chi', s.expense, Colors.red),
                    const Divider(),
                    _row(context, 'Còn lại', s.net,
                        s.net >= 0 ? Colors.green : Colors.red),
                  ],
                ),
              ),
            ),
            // Always-present budget card (rows when budgets exist; otherwise a
            // "Thêm ngân sách →" tap target so the first budget has an entry point).
            Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BudgetsScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text('Ngân sách'),
                      ),
                      if (budgets.isEmpty)
                        const ListTile(
                          dense: true,
                          title: Text('Thêm ngân sách →'),
                        )
                      else
                        for (final b in budgets)
                          BudgetTile(
                            name: b.categoryId == null
                                ? 'Tổng'
                                : (catName[b.categoryId] ?? '—'),
                            spent: spentInMonth(txns, month,
                                categoryId: b.categoryId),
                            limit: b.amount,
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Gần đây'),
            ),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Chưa có giao dịch nào')),
              ),
            for (final t in recent)
              ListTile(
                leading: Icon(t.type == TransactionType.income
                    ? Icons.south_west
                    : t.type == TransactionType.expense
                        ? Icons.north_east
                        : Icons.swap_horiz),
                title: Text(catName[t.categoryId] ??
                    (t.type == TransactionType.transfer ? 'Chuyển ví' : '—')),
                subtitle: Text(formatDmy(t.occurredAt) +
                    (t.note.isEmpty ? '' : ' · ${t.note}')),
                trailing: Text(
                  (t.type == TransactionType.expense
                          ? '-'
                          : t.type == TransactionType.transfer
                              ? ''
                              : '+') +
                      formatVnd(t.amount),
                  style: TextStyle(
                    color: t.type == TransactionType.expense
                        ? Colors.red
                        : t.type == TransactionType.transfer
                            ? Colors.grey
                            : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext c, String label, int amount, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(formatVnd(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
