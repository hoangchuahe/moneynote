import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/state/providers.dart';

/// Leading cho BudgetTile: ô icon danh mục, hoặc ví tổng khi ngân sách Tổng.
Widget budgetLeading(BuildContext context, Category? category) =>
    category == null
        ? Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance_wallet,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          )
        : CategoryIconBox(iconName: category.icon, color: category.color);

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catById = {for (final c in categories) c.id: c};
    final month = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách')),
      body: budgets.isEmpty
          ? const EmptyState(
              icon: Icons.savings,
              title: 'Chưa có ngân sách nào',
              hint: 'Đặt hạn mức cho một danh mục để app nhắc khi sắp vượt')
          : ListView(
              children: [
                for (final b in budgets)
                  BudgetTile(
                    name: b.categoryId == null
                        ? 'Tổng'
                        : (catById[b.categoryId]?.name ?? 'Chưa phân loại'),
                    leading: budgetLeading(context, catById[b.categoryId]),
                    spent: spentInMonth(txns, month, categoryId: b.categoryId),
                    limit: b.amount,
                    onTap: () => _editBudget(context, ref, b),
                    onLongPress: () => _confirmDelete(context, ref, b),
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
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Hạn mức/tháng'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final amount = parseVndInput(amountCtrl.text);
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
    amountCtrl.dispose();
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, Budget b) async {
    final amountCtrl = TextEditingController(text: groupThousands(b.amount));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa hạn mức'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: const InputDecoration(labelText: 'Hạn mức/tháng'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              final amount = parseVndInput(amountCtrl.text);
              if (amount <= 0) return;
              ref.read(repositoryProvider).upsertBudget(b.categoryId, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    amountCtrl.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Budget b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ngân sách này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xoá')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(repositoryProvider).deleteBudget(b.id);
    }
  }
}

/// Progress tile dùng ở màn Ngân sách và card ngân sách trên Tổng quan.
/// Trạng thái màu: vượt 100% = expense (+ chip "vượt"), từ 80% = warn,
/// dưới đó = primary.
class BudgetTile extends StatelessWidget {
  final String name;
  final int spent;
  final int limit;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const BudgetTile({
    super.key,
    required this.name,
    required this.spent,
    required this.limit,
    this.leading,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final money = moneyColorsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final over = spent > limit;
    final ratioRaw = limit <= 0 ? 0.0 : spent / limit;
    final ratio = ratioRaw.clamp(0.0, 1.0);
    final barColor = over
        ? money.expense
        : ratioRaw >= 0.8
            ? money.warn
            : scheme.primary;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading,
      title: Text(name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: barColor,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatVnd(spent)} / ${formatVnd(limit)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: over ? money.expense : scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              if (over)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: money.expense.withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('vượt',
                      style: TextStyle(fontSize: 11, color: money.expense)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
