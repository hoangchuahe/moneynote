import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/transaction_filter.dart';
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
                    hintText: 'Tìm theo ghi chú…',
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
              final txns = filterTransactions(all, filter);
              if (txns.isEmpty) {
                return Center(
                    child: Text(filter.isActive
                        ? 'Không có giao dịch khớp'
                        : 'Chưa có giao dịch nào'));
              }
              return ListView(
                children: [
                  for (final t in txns)
                    Dismissible(
                      key: Key('txn_${t.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
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
                            content: const Text('Đã xoá giao dịch'),
                            action: SnackBarAction(
                              label: 'Hoàn tác',
                              onPressed: () => repo.restoreTransaction(t.id),
                            ),
                          ));
                      },
                      child: ListTile(
                        title: Text(catName[t.categoryId] ??
                            (t.type == TransactionType.transfer
                                ? 'Chuyển ví'
                                : '—')),
                        subtitle: Text(formatDmy(t.occurredAt) +
                            (t.note.isEmpty ? '' : ' · ${t.note}')),
                        trailing: Text(
                          (t.type == TransactionType.expense ? '-' : '+') +
                              formatVnd(t.amount),
                          style: TextStyle(
                            color: t.type == TransactionType.expense
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ),
                    ),
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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final f = ref.read(txnFilterProvider);
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
                            ref.read(txnFilterProvider.notifier).state =
                                f.copyWith(categoryIds: next);
                            setSheet(() {});
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
                            ref.read(txnFilterProvider.notifier).state =
                                f.copyWith(
                              from: DateTime(range.start.year,
                                  range.start.month, range.start.day),
                              to: DateTime(range.end.year, range.end.month,
                                  range.end.day, 23, 59, 59),
                            );
                            setSheet(() {});
                          }
                        },
                        child: Text(f.from == null
                            ? 'Chọn khoảng ngày'
                            : '${f.from!.day}/${f.from!.month} – ${f.to!.day}/${f.to!.month}'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          ref.read(txnFilterProvider.notifier).state =
                              const TxnFilter();
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
        );
      },
    );
  }
}
