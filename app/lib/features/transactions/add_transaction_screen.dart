import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/ai_models.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  /// When [existing] is set the screen edits that transaction in place
  /// instead of creating a new one.
  const AddTransactionScreen(
      {super.key, this.existing, this.initialTransferFromWalletId});

  final Transaction? existing;
  final String? initialTransferFromWalletId;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _smartCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _walletId;
  String? _toWalletId;
  DateTime _date = DateTime.now();
  bool _parsing = false;
  String? _merchant;
  String? _aiSuggestedCategoryId;
  String? _aiComment;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _amountCtrl.text = groupThousands(t.amount);
      _noteCtrl.text = t.note;
      _type = t.type;
      _categoryId = t.categoryId;
      _walletId = t.walletId;
      _toWalletId = t.toWalletId;
      _date = t.occurredAt;
    } else if (widget.initialTransferFromWalletId != null) {
      _type = TransactionType.transfer;
      _walletId = widget.initialTransferFromWalletId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _smartCtrl.dispose();
    super.dispose();
  }

  String? _firstWhereNameId(List<Category> cats, String name) {
    for (final c in cats) {
      if (c.name == name) return c.id;
    }
    return null;
  }

  Future<void> _runSmartParse() async {
    final text = _smartCtrl.text.trim();
    if (text.isEmpty) return;
    final client = ref.read(aiClientProvider);
    if (client == null) return;
    final prefs = await ref.read(prefsProvider.future);
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    setState(() {
      _parsing = true;
      _merchant = null;
      _aiSuggestedCategoryId = null;
      _aiComment = null;
    });
    try {
      final today = DateTime.now();
      final res = await client.parse(ParseRequest(
        text: text,
        today:
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        tone: prefs.tone,
        categories: cats.map((c) => c.name).toList(),
        wallets:
            (ref.read(walletsProvider).valueOrNull ?? []).map((w) => w.name).toList(),
      ));

      String? catId = res.category == null ? null : _firstWhereNameId(cats, res.category!);
      if (res.merchant != null) {
        final learned = await ref.read(repositoryProvider).lookupMerchant(res.merchant!);
        if (learned != null) catId = learned.id;
      }

      if (!mounted) return;
      setState(() {
        _type = res.type == 'income' ? TransactionType.income : TransactionType.expense;
        // Spec §9: chỉ pre-fill field AI parse được — không điền 0 bừa.
        if (res.amount > 0) _amountCtrl.text = groupThousands(res.amount);
        _categoryId = catId;
        _aiSuggestedCategoryId = catId;
        _merchant = res.merchant;
        _aiComment = res.comment.isEmpty ? null : res.comment;
        if (res.note.isNotEmpty) _noteCtrl.text = res.note;
      });
    } on AiException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI không khả dụng, nhập tay nhé')));
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Widget _dateTile() => ListTile(
        leading: const Icon(Icons.calendar_today, size: 20),
        title: const Text('Ngày'),
        trailing: Text(formatDmy(_date)),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => _date = picked);
        },
      );

  CategoryType get _catType => switch (_type) {
        TransactionType.income => CategoryType.income,
        // expense + transfer (transfer has no category UI in P1) -> expense list
        TransactionType.expense || TransactionType.transfer =>
          CategoryType.expense,
      };

  Future<void> _save() async {
    final amount = parseVndInput(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập số tiền hợp lệ')));
      return;
    }
    if (_type == TransactionType.transfer) {
      final from = _walletId;
      final to = _toWalletId;
      if (from == null || to == null || from == to) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chọn hai ví khác nhau')));
        return;
      }
      final repo = ref.read(repositoryProvider);
      if (_isEditing) {
        await repo.updateTransaction(
          widget.existing!.id,
          amount: amount,
          type: TransactionType.transfer,
          walletId: from,
          toWalletId: to,
          note: _noteCtrl.text.trim(),
          occurredAt: _date,
        );
      } else {
        await repo.addTransaction(
          amount: amount,
          type: TransactionType.transfer,
          walletId: from,
          toWalletId: to,
          note: _noteCtrl.text.trim(),
          occurredAt: _date,
        );
      }
      if (mounted) Navigator.of(context).pop();
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
    if (_merchant != null && _categoryId != _aiSuggestedCategoryId && _categoryId != null) {
      await ref.read(repositoryProvider).upsertMerchant(_merchant!, _categoryId!);
    }
    final repo = ref.read(repositoryProvider);
    if (_isEditing) {
      await repo.updateTransaction(
        widget.existing!.id,
        amount: amount,
        type: _type,
        categoryId: _categoryId,
        walletId: walletId,
        note: _noteCtrl.text.trim(),
        occurredAt: _date,
      );
    } else {
      await repo.addTransaction(
        amount: amount,
        type: _type,
        categoryId: _categoryId,
        walletId: walletId,
        note: _noteCtrl.text.trim(),
        occurredAt: _date,
      );
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
      appBar:
          AppBar(title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Smart input chỉ cho nhập mới — sửa là thao tác tay có chủ đích.
          if (!_isEditing && _type != TransactionType.transfer) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('smartInput'),
                    controller: _smartCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Gõ "trưa nay ăn phở 50k"…',
                      prefixIcon: Icon(Icons.auto_awesome),
                    ),
                    onSubmitted: (_) => _runSmartParse(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('parseButton'),
                  onPressed: _parsing ? null : _runSmartParse,
                  child: _parsing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Phân tích'),
                ),
              ],
            ),
            if (_aiComment != null)
              Container(
                key: const Key('aiCommentCard'),
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                decoration: BoxDecoration(
                  color: moneyColorsOf(context).warnContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 16, color: moneyColorsOf(context).onWarnContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_aiComment!,
                          style: TextStyle(
                              fontSize: 13,
                              color: moneyColorsOf(context).onWarnContainer)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close,
                          size: 16,
                          color: moneyColorsOf(context).onWarnContainer),
                      onPressed: () => setState(() => _aiComment = null),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
          ],
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                  value: TransactionType.expense, label: Text('Chi')),
              ButtonSegment(value: TransactionType.income, label: Text('Thu')),
              ButtonSegment(value: TransactionType.transfer, label: Text('Chuyển')),
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
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '0',
              suffixText: '₫',
            ),
          ),
          const SizedBox(height: 16),
          if (_type != TransactionType.transfer) ...[
            Text('Danh mục', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    key: Key('cat_${c.name}'),
                    avatar: Icon(categoryIcon(c.icon),
                        size: 16,
                        color: _categoryId == c.id
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Color(c.color)),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_type == TransactionType.transfer) ...[
            DropdownButtonFormField<String>(
              key: const Key('fromWallet'),
              initialValue: _walletId,
              decoration: const InputDecoration(labelText: 'Từ ví'),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _walletId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('toWallet'),
              initialValue: _toWalletId,
              decoration: const InputDecoration(labelText: 'Đến ví'),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _toWalletId = v),
            ),
            const SizedBox(height: 16),
            Card(margin: EdgeInsets.zero, child: _dateTile()),
          ] else
            // Spec UI redesign §5: ví + ngày gộp một card hai dòng.
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined,
                        size: 20),
                    title: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('walletDropdown'),
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
                  _dateTile(),
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
            key: const Key('saveButton'),
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
