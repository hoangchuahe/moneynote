import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/features/budgets/budgets_screen.dart'; // budgetLeading
import 'package:moneynote/state/providers.dart';

/// Add/edit a budget: a big amount field + a category picker (Tổng + expense
/// categories). Replaces the old _addBudget / _editBudget dialogs.
class BudgetEditScreen extends ConsumerStatefulWidget {
  const BudgetEditScreen({super.key, this.existing});

  final Budget? existing;

  @override
  ConsumerState<BudgetEditScreen> createState() => _BudgetEditScreenState();
}

typedef _Option = ({String? id, String label});

class _BudgetEditScreenState extends ConsumerState<BudgetEditScreen> {
  late final TextEditingController _amountCtrl;
  // Selection keyed by id ('overall' for the null/Tổng budget) — survives a
  // budgetsProvider emission that reorders/shrinks the options list.
  String? _selKey;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: _isEditing ? groupThousands(widget.existing!.amount) : '');
    if (_isEditing) _selKey = widget.existing!.categoryId ?? 'overall';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<_Option> options) async {
    final amount = parseVndInput(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nhập hạn mức')));
      return;
    }
    final navigator = Navigator.of(context);
    final repo = ref.read(repositoryProvider);
    final chosen = options.firstWhere(
      (o) => (o.id ?? 'overall') == _selKey,
      orElse: () => options.first,
    );
    await repo.upsertBudget(chosen.id, amount);
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catById = {for (final c in categories) c.id: c};

    final options = <_Option>[];
    if (_isEditing) {
      final id = widget.existing!.categoryId;
      options.add((
        id: id,
        label: id == null
            ? 'Tổng (tất cả)'
            : (catById[id]?.name ?? 'Chưa phân loại'),
      ));
    } else {
      final taken = budgets.map((x) => x.categoryId).toSet();
      if (!taken.contains(null)) {
        options.add((id: null, label: 'Tổng (tất cả)'));
      }
      for (final c in categories.where((c) => c.type == CategoryType.expense)) {
        if (!taken.contains(c.id)) options.add((id: c.id, label: c.name));
      }
    }

    final selKey =
        _selKey ?? (options.isEmpty ? null : (options.first.id ?? 'overall'));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa hạn mức' : 'Thêm ngân sách'),
        actions: [
          TextButton(
            key: const Key('saveBudget'),
            onPressed: options.isEmpty ? null : () => _save(options),
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: options.isEmpty
          ? const Center(child: Text('Đã đặt ngân sách cho mọi danh mục'))
          : ListView(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    key: const Key('budgetAmount'),
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsInputFormatter()],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      suffixText: '₫',
                      border: InputBorder.none,
                      hintText: '0',
                    ),
                  ),
                ),
                Center(
                  child: Text('mỗi tháng',
                      style:
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 12),
                InsetSection(
                  header: 'Danh mục',
                  children: [
                    for (final o in options)
                      InsetRow(
                        key: Key('budgetCat_${o.id ?? 'overall'}'),
                        leading: budgetLeading(context, catById[o.id]),
                        title: o.label,
                        onTap: _isEditing
                            ? null
                            : () => setState(() => _selKey = o.id ?? 'overall'),
                        trailing: (o.id ?? 'overall') == selKey
                            ? Icon(Icons.check, size: 22, color: cs.primary)
                            : null,
                      ),
                  ],
                ),
                if (_isEditing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text('Không thể đổi danh mục',
                        style:
                            TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
    );
  }
}
