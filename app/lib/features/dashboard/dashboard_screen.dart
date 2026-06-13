import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/domain/txn_grouping.dart';
import 'package:moneynote/features/budgets/budgets_screen.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/state/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];

    return txnsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (txns) {
        final s = summarize(txns, month);
        final catById = {for (final c in categories) c.id: c};
        final recentGroups = groupByDay(txns.take(15).toList(), DateTime.now());
        final money = moneyColorsOf(context);
        return ListView(
          padding: EdgeInsets.only(bottom: pillClearance(context)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('prevMonth'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        ref.read(selectedMonthProvider.notifier).state =
                            DateTime(month.year, month.month - 1, 1),
                  ),
                  Text('Tháng ${month.month}/${month.year}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  IconButton(
                    key: const Key('nextMonth'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        ref.read(selectedMonthProvider.notifier).state =
                            DateTime(month.year, month.month + 1, 1),
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Còn lại tháng này',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      formatVnd(s.net),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: s.net >= 0 ? money.income : money.expense,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _stat(context, 'Thu', s.income, money.income)),
                        SizedBox(
                            height: 28,
                            child: VerticalDivider(
                                width: 1,
                                color: Theme.of(context).colorScheme.outline)),
                        Expanded(
                            child: _stat(
                                context, 'Chi', s.expense, money.expense)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Always-present budget card (rows when budgets exist; otherwise a
            // "Thêm ngân sách →" tap target so the first budget has an entry point).
            Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BudgetsScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text('Ngân sách',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
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
                                : (catById[b.categoryId]?.name ??
                                    'Chưa phân loại'),
                            leading:
                                budgetLeading(context, catById[b.categoryId]),
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
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('Gần đây',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            if (txns.isEmpty)
              const EmptyState(
                  icon: Icons.receipt_long,
                  title: 'Chưa có giao dịch nào',
                  hint: "Bấm Thêm rồi gõ 'ăn phở 50k' là xong"),
            for (final g in recentGroups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(g.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              for (final t in g.txns)
                TransactionTile(
                  txn: t,
                  category: catById[t.categoryId],
                  onTap: () => openTransactionDetail(context, t.id),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext c, String label, int amount, Color color) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(c).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(formatVnd(amount),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      );
}
