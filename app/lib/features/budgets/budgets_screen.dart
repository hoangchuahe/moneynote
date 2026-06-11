import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/state/providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};
    final month = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách')),
      body: budgets.isEmpty
          ? const Center(child: Text('Chưa có ngân sách nào'))
          : ListView(
              children: [
                for (final b in budgets)
                  BudgetTile(
                    name: b.categoryId == null
                        ? 'Tổng'
                        : (catName[b.categoryId] ?? '—'),
                    spent: spentInMonth(txns, month, categoryId: b.categoryId),
                    limit: b.amount,
                    onTap: () => _editBudget(context, ref, b),
                    onLongPress: () =>
                        ref.read(repositoryProvider).deleteBudget(b.id),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBudget(context, ref, categories),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addBudget(
      BuildContext context, WidgetRef ref, List<Category> categories) async {
    final expenseCats =
        categories.where((c) => c.type == CategoryType.expense).toList();
    String? categoryId; // null = Tổng
    final amountCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Thêm ngân sách'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String?>(
                value: categoryId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tổng')),
                  for (final c in expenseCats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => categoryId = v),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Hạn mức/tháng'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                ref.read(repositoryProvider).upsertBudget(categoryId, amount);
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, Budget b) async {
    final amountCtrl = TextEditingController(text: b.amount.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa hạn mức'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Hạn mức/tháng'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              ref.read(repositoryProvider).upsertBudget(b.categoryId, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

/// Progress tile reused by the Budgets screen and the dashboard budget card.
class BudgetTile extends StatelessWidget {
  final String name;
  final int spent;
  final int limit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const BudgetTile({
    super.key,
    required this.name,
    required this.spent,
    required this.limit,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final over = spent > limit;
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: ratio, color: over ? Colors.red : null),
          const SizedBox(height: 4),
          Text(
            '${formatVnd(spent)} / ${formatVnd(limit)}${over ? '  ⚠ vượt' : ''}',
            style: TextStyle(color: over ? Colors.red : null),
          ),
        ],
      ),
    );
  }
}
