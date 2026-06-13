import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/features/categories/category_edit_screen.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/state/providers.dart';

/// Pushes the read-only category detail, double-tap-guarded like
/// [openTransactionDetail].
void openCategoryDetail(BuildContext context, String categoryId) {
  if (ModalRoute.of(context)?.isCurrent ?? true) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryDetailScreen(categoryId)),
    );
  }
}

/// Read-only category detail: a colour-tinted header (icon · name·type ·
/// all-time total · Sửa) over this category's recent transactions, plus a
/// destructive delete row.
class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen(this.categoryId, {super.key});

  final String categoryId;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  // Once shown, a later disappearance (delete) renders blank instead of the
  // not-found guard, so deleting never flashes the error screen.
  Category? _last;

  Future<void> _confirmDelete(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá danh mục "${c.name}"?'),
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
    // Pop FIRST (animated); the _last cache keeps the exiting frame from
    // re-resolving to null and flashing the not-found guard.
    navigator.pop();
    repo.softDeleteCategory(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];

    Category? found;
    for (final x in categories) {
      if (x.id == widget.categoryId) {
        found = x;
        break;
      }
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Danh mục')),
        body: _last != null
            ? null
            : const Center(child: Text('Danh mục không tồn tại')),
      );
    }
    _last = found;
    final c = found;

    final money = moneyColorsOf(context);
    final color = Color(c.color);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final typeLabel = c.type == CategoryType.expense ? 'Chi' : 'Thu';
    final mine = txns.where((t) => t.categoryId == c.id).take(15).toList();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            key: const Key('categoryDetailHeader'),
            color: color,
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
                        CategoryIconBox(
                            iconName: c.icon, color: c.color, size: 56),
                        const SizedBox(height: 10),
                        Text('${c.name} · $typeLabel',
                            style: TextStyle(
                                fontSize: 14, color: onColor.withAlpha(209))),
                        const SizedBox(height: 6),
                        Text(formatVnd(categoryTotal(c.id, txns)),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              color: onColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                        const SizedBox(height: 16),
                        GestureDetector(
                          key: const Key('categoryEdit'),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CategoryEditScreen(existing: c))),
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
                    category: c,
                    onTap: () => openTransactionDetail(context, t.id),
                  ),
              ],
            ),
          InsetSection(
            children: [
              InsetRow(
                key: const Key('deleteCategory'),
                leading: Icon(Icons.delete, size: 22, color: money.expense),
                title: 'Xoá danh mục',
                destructive: true,
                onTap: () => _confirmDelete(c),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
