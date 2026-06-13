import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/budget_donut.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/features/budgets/budget_edit_screen.dart';
import 'package:moneynote/features/budgets/budgets_screen.dart'; // budgetLevelColor
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/state/providers.dart';

/// Pushes the read-only budget detail, double-tap-guarded like
/// [openTransactionDetail]/[openCategoryDetail].
void openBudgetDetail(BuildContext context, String budgetId) {
  if (ModalRoute.of(context)?.isCurrent ?? true) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BudgetDetailScreen(budgetId)),
    );
  }
}

/// Read-only budget detail: a colour-tinted header, a donut (% used), a
/// three-column stat row, this month's transactions, and a destructive delete.
class BudgetDetailScreen extends ConsumerStatefulWidget {
  const BudgetDetailScreen(this.budgetId, {super.key});

  final String budgetId;

  @override
  ConsumerState<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<BudgetDetailScreen> {
  Budget? _last;

  Future<void> _confirmDelete(Budget b) async {
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
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    final repo = ref.read(repositoryProvider);
    navigator.pop();
    repo.deleteBudget(b.id);
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final month = ref.watch(selectedMonthProvider);

    Budget? found;
    for (final x in budgets) {
      if (x.id == widget.budgetId) {
        found = x;
        break;
      }
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ngân sách')),
        body: _last != null
            ? null
            : const Center(child: Text('Ngân sách không tồn tại')),
      );
    }
    _last = found;
    final b = found;

    final money = moneyColorsOf(context);
    final cs = Theme.of(context).colorScheme;
    final catById = {for (final c in categories) c.id: c};
    final cat = b.categoryId == null ? null : catById[b.categoryId];
    final name = cat?.name ?? 'Tổng';
    final headerColor = cat != null ? Color(cat.color) : cs.primary;
    final onColor =
        ThemeData.estimateBrightnessForColor(headerColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    final spent = spentInMonth(txns, month, categoryId: b.categoryId);
    final p = BudgetProgress(spent, b.amount);
    final ringColor = budgetLevelColor(context, p.level);
    final mine = txns
        .where((t) =>
            t.type == TransactionType.expense &&
            inMonth(t.occurredAt, month) &&
            (b.categoryId == null || t.categoryId == b.categoryId))
        .take(15)
        .toList();

    Widget headerIcon() => cat != null
        ? CategoryIconBox(iconName: cat.icon, color: cat.color, size: 56)
        : Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: onColor.withAlpha(46),
                borderRadius: BorderRadius.circular(16)),
            child:
                Icon(Icons.account_balance_wallet, size: 28, color: onColor),
          );

    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        );

    final over = p.level == BudgetLevel.over;
    final divider = Container(width: 0.5, height: 30, color: cs.outlineVariant);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            key: const Key('budgetDetailHeader'),
            color: headerColor,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new,
                              color: onColor, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 22),
                    child: Column(
                      children: [
                        headerIcon(),
                        const SizedBox(height: 10),
                        Text('$name · Ngân sách',
                            style: TextStyle(
                                fontSize: 14, color: onColor.withAlpha(209))),
                        const SizedBox(height: 16),
                        GestureDetector(
                          key: const Key('budgetEdit'),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      BudgetEditScreen(existing: b))),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: onColor.withAlpha(46),
                                    shape: BoxShape.circle),
                                child:
                                    Icon(Icons.tune, size: 22, color: onColor),
                              ),
                              const SizedBox(height: 5),
                              Text('Sửa',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: onColor.withAlpha(230))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Center(
              child: BudgetDonut(
                ratio: p.ratio,
                color: ringColor,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${p.percent}%',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w600)),
                    Text('đã dùng',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                stat('Đã chi', formatVnd(p.spent), money.expense),
                divider,
                if (over)
                  stat('Vượt', formatVnd(p.spent - p.limit), money.expense)
                else
                  stat('Còn lại', formatVnd(p.remaining), money.income),
                divider,
                stat('Hạn mức', formatVnd(p.limit), cs.onSurface),
              ],
            ),
          ),
          if (mine.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Chưa có giao dịch')),
            )
          else
            InsetSection(
              header: 'Gần đây',
              children: [
                for (final t in mine)
                  TransactionTile(
                    txn: t,
                    category: catById[t.categoryId],
                    onTap: () => openTransactionDetail(context, t.id),
                  ),
              ],
            ),
          InsetSection(
            children: [
              InsetRow(
                key: const Key('deleteBudget'),
                leading: Icon(Icons.delete, size: 22, color: money.expense),
                title: 'Xoá ngân sách',
                destructive: true,
                onTap: () => _confirmDelete(b),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
