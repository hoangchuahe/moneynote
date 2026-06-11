import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};

    return txnsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (txns) {
        if (txns.isEmpty) {
          return const Center(child: Text('Chưa có giao dịch nào'));
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
    );
  }
}
