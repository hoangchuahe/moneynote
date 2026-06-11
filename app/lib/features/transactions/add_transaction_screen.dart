import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _walletId;
  DateTime _date = DateTime.now();

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
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập số tiền hợp lệ')),
      );
      return;
    }
    final wallets = ref.read(walletsProvider).valueOrNull ?? [];
    final walletId = _walletId ?? (wallets.isNotEmpty ? wallets.first.id : null);
    if (walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ví nào')),
      );
      return;
    }
    await ref.read(repositoryProvider).addTransaction(
          amount: amount,
          type: _type,
          categoryId: _categoryId,
          walletId: walletId,
          note: _noteCtrl.text.trim(),
          occurredAt: _date,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final cats = categories.where((c) => c.type == _catType).toList();
    _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm giao dịch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                  value: TransactionType.expense, label: Text('Chi')),
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
            key: const Key('amountField'),
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Số tiền (đồng)',
              suffixText: '₫',
            ),
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
                  key: Key('cat_${c.name}'),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('walletDropdown'),
            initialValue: _walletId,
            decoration: const InputDecoration(labelText: 'Ví'),
            items: [
              for (final w in wallets)
                DropdownMenuItem(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) => setState(() => _walletId = v),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày'),
            subtitle: Text(
                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('saveButton'),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
