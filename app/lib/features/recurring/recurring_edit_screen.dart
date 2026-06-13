import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

String cycleLabel(RecurringCycle c) => switch (c) {
      RecurringCycle.daily => 'Hàng ngày',
      RecurringCycle.weekly => 'Hàng tuần',
      RecurringCycle.monthly => 'Hàng tháng',
      RecurringCycle.yearly => 'Hàng năm',
    };

class RecurringEditScreen extends ConsumerStatefulWidget {
  const RecurringEditScreen({super.key, this.existing});

  final Recurring? existing;

  @override
  ConsumerState<RecurringEditScreen> createState() => _RecurringEditScreenState();
}

class _RecurringEditScreenState extends ConsumerState<RecurringEditScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  RecurringCycle _cycle = RecurringCycle.monthly;
  String? _categoryId;
  String? _walletId;
  DateTime _start = DateTime.now();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _amountCtrl.text = groupThousands(r.amount);
      _noteCtrl.text = r.note;
      _type = r.type;
      _cycle = r.cycle;
      _categoryId = r.categoryId;
      _walletId = r.walletId;
      _start = r.startDate;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  CategoryType get _catType => _type == TransactionType.income
      ? CategoryType.income
      : CategoryType.expense;

  Future<void> _save() async {
    final amount = parseVndInput(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập số tiền hợp lệ')));
      return;
    }
    final wallets = ref.read(walletsProvider).valueOrNull ?? [];
    final walletId = _walletId ?? (wallets.isNotEmpty ? wallets.first.id : null);
    if (walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có ví nào')));
      return;
    }
    final repo = ref.read(repositoryProvider);
    if (_isEditing) {
      await repo.updateRecurring(widget.existing!.id,
          amount: amount, type: _type, categoryId: _categoryId, walletId: walletId,
          note: _noteCtrl.text.trim(), cycle: _cycle, startDate: _start);
    } else {
      await repo.addRecurring(
          amount: amount, type: _type, categoryId: _categoryId, walletId: walletId,
          note: _noteCtrl.text.trim(), cycle: _cycle, startDate: _start);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final cats = categories.where((c) => c.type == _catType).toList();
    _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Sửa định kỳ' : 'Thêm định kỳ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TransactionType>(
            key: const Key('recurringType'),
            segments: const [
              ButtonSegment(value: TransactionType.expense, label: Text('Chi')),
              ButtonSegment(value: TransactionType.income, label: Text('Thu')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('recurringAmount'),
            controller: _amountCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(hintText: '0', suffixText: '₫'),
          ),
          const SizedBox(height: 16),
          Text('Danh mục', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                ChoiceChip(
                  key: Key('rcat_${c.name}'),
                  avatar: Icon(categoryIcon(c.icon),
                      size: 16,
                      color: _categoryId == c.id
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Color(c.color)),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Chu kỳ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<RecurringCycle>(
            key: const Key('cycleSegment'),
            segments: [
              for (final c in RecurringCycle.values)
                ButtonSegment(value: c, label: Text(cycleLabel(c))),
            ],
            selected: {_cycle},
            onSelectionChanged: (s) => setState(() => _cycle = s.first),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                  title: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('recurringWallet'),
                      value: _walletId,
                      isExpanded: true,
                      items: [
                        for (final w in wallets)
                          DropdownMenuItem(value: w.id, child: Text(w.name)),
                      ],
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('recurringDate'),
                  leading: const Icon(Icons.event, size: 20),
                  title: const Text('Bắt đầu'),
                  trailing: Text(formatDmy(_start)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('recurringSave'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? 'Lưu thay đổi' : 'Lưu'),
          ),
        ],
      ),
    );
  }
}
