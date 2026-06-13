import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/transaction_filter.dart';
import 'package:moneynote/domain/txn_grouping.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/state/providers.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};
    final filter = ref.watch(txnFilterProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('searchField'),
                  decoration: const InputDecoration(
                    hintText: 'Tìm ghi chú, danh mục…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => ref.read(txnFilterProvider.notifier).state =
                      filter.copyWith(text: v),
                ),
              ),
              IconButton(
                key: const Key('filterButton'),
                icon: Icon(filter.isActive
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
                onPressed: () => _openFilterSheet(context, ref, categories),
              ),
            ],
          ),
        ),
        Expanded(
          child: txnsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e')),
            data: (all) {
              final txns =
                  filterTransactions(all, filter, categoryNameById: catName);
              if (txns.isEmpty) {
                return filter.isActive
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Không có giao dịch khớp')
                    : const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'Chưa có giao dịch nào',
                        hint: "Bấm Thêm rồi gõ 'ăn phở 50k' là xong");
              }
              final catById = {for (final c in categories) c.id: c};
              final groups = groupByDay(txns, DateTime.now());
              final deleteColor = moneyColorsOf(context).expense;
              return ListView(
                padding: EdgeInsets.only(bottom: pillClearance(context)),
                children: [
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                      child: Text(g.label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ),
                    for (final t in g.txns)
                      Dismissible(
                        key: Key('txn_${t.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: deleteColor,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          final repo = ref.read(repositoryProvider);
                          repo.softDeleteTransaction(t.id);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              margin: EdgeInsets.only(
                                  bottom: pillClearance(context),
                                  left: 12,
                                  right: 12),
                              content: const Text('Đã xoá giao dịch'),
                              action: SnackBarAction(
                                label: 'Hoàn tác',
                                onPressed: () => repo.restoreTransaction(t.id),
                              ),
                            ));
                        },
                        child: TransactionTile(
                          txn: t,
                          category: catById[t.categoryId],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddTransactionScreen(existing: t)),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openFilterSheet(
      BuildContext context, WidgetRef ref, List<Category> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final f = ref.watch(txnFilterProvider);
          final notifier = ref.read(txnFilterProvider.notifier);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Danh mục'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in categories)
                      FilterChip(
                        label: Text(c.name),
                        selected: f.categoryIds.contains(c.id),
                        onSelected: (sel) {
                          final next = {...f.categoryIds};
                          sel ? next.add(c.id) : next.remove(c.id);
                          notifier.state = f.copyWith(categoryIds: next);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (range != null) {
                          notifier.state = f.copyWith(
                            from: DateTime(range.start.year, range.start.month,
                                range.start.day),
                            to: DateTime(range.end.year, range.end.month,
                                range.end.day, 23, 59, 59),
                          );
                        }
                      },
                      child: Text(f.from == null
                          ? 'Chọn khoảng ngày'
                          : '${f.from!.day}/${f.from!.month} – ${f.to!.day}/${f.to!.month}'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        notifier.state = TxnFilter(text: f.text); // keep search text
                        Navigator.pop(ctx);
                      },
                      child: const Text('Xoá lọc'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
