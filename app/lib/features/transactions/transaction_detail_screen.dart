import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/state/providers.dart';

/// Pushes the read-only transaction detail, guarded so a double-tap can't stack
/// two copies (the originating route is no longer current after the first push).
void openTransactionDetail(BuildContext context, String transactionId) {
  if (ModalRoute.of(context)?.isCurrent ?? true) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId)),
    );
  }
}

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen(this.transactionId, {super.key});

  final String transactionId;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  // Once a txn has been shown, a later disappearance (delete/edit) renders blank
  // instead of the not-found error, so deleting never flashes the error screen.
  Transaction? _last;

  String _formatDate(DateTime d) => '${d.day} thg ${d.month}, ${d.year}';

  void _delete(Transaction t) {
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final clearance = pillClearance(context);
    // Pop FIRST (animated, so the back-slide is preserved); the _last cache in
    // build() keeps the exiting frame from re-resolving to null and flashing the
    // not-found guard. The snackbar then lands on the returned-to screen.
    navigator.pop();
    repo.softDeleteTransaction(t.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: clearance, left: 12, right: 12),
        content: const Text('Đã xoá giao dịch'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () => repo.restoreTransaction(t.id),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    // Watch all three providers eagerly so they all start loading in the same
    // render cycle (avoids a sequential: txns-loads → cats-loads → wallets-loads
    // chain that would need extra pumps in tests).
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];

    Transaction? txn;
    for (final t in txns) {
      if (t.id == widget.transactionId) {
        txn = t;
        break;
      }
    }
    if (txn == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết')),
        body: _last != null
            ? null
            : const Center(child: Text('Giao dịch không tồn tại')),
      );
    }
    _last = txn;
    final t = txn;

    final cs = Theme.of(context).colorScheme;
    final money = moneyColorsOf(context);
    final catById = {for (final c in categories) c.id: c};
    final walletById = {for (final w in wallets) w.id: w};

    final isTransfer = t.type == TransactionType.transfer;
    final cat = t.categoryId == null ? null : catById[t.categoryId];
    final typeColor = switch (t.type) {
      TransactionType.income => money.income,
      TransactionType.expense => money.expense,
      TransactionType.transfer => money.transfer,
    };
    final heroName = isTransfer ? 'Chuyển ví' : (cat?.name ?? 'Chưa phân loại');
    final typeLabel = switch (t.type) {
      TransactionType.income => 'Khoản thu',
      TransactionType.expense => 'Khoản chi',
      TransactionType.transfer => 'Chuyển ví',
    };
    final muted = cs.onSurfaceVariant;
    Widget fieldIcon(IconData i) => Icon(i, size: 22, color: muted);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết'),
        actions: [
          TextButton(
            key: const Key('editTxn'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddTransactionScreen(existing: t))),
            child: const Text('Sửa'),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
            child: Column(
              children: [
                if (isTransfer)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: money.transfer.withAlpha(36),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                        Icon(Icons.swap_horiz, size: 32, color: money.transfer),
                  )
                else
                  CategoryIconBox(
                    iconName: cat?.icon ?? 'category',
                    color: cat?.color ?? 0xFF9E9E9E,
                    size: 64,
                  ),
                const SizedBox(height: 10),
                Text(heroName, style: TextStyle(fontSize: 13, color: muted)),
                const SizedBox(height: 4),
                Text(
                  formatVnd(t.amount),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(_formatDate(t.occurredAt),
                    style: TextStyle(fontSize: 14, color: muted)),
              ],
            ),
          ),
          InsetSection(children: [
            if (!isTransfer)
              InsetRow(
                leading: CategoryIconBox(
                    iconName: cat?.icon ?? 'category',
                    color: cat?.color ?? 0xFF9E9E9E,
                    size: 24),
                title: 'Danh mục',
                value: cat?.name ?? 'Chưa phân loại',
              ),
            if (isTransfer) ...[
              InsetRow(
                  leading: fieldIcon(Icons.account_balance_wallet),
                  title: 'Từ ví',
                  value: walletById[t.walletId]?.name ?? '—'),
              InsetRow(
                  leading: fieldIcon(Icons.account_balance_wallet),
                  title: 'Đến ví',
                  value: walletById[t.toWalletId]?.name ?? '—'),
            ] else
              InsetRow(
                  leading: fieldIcon(Icons.account_balance_wallet),
                  title: 'Ví',
                  value: walletById[t.walletId]?.name ?? '—'),
            InsetRow(
                leading: fieldIcon(Icons.calendar_today),
                title: 'Ngày',
                value: _formatDate(t.occurredAt)),
            InsetRow(
                leading: fieldIcon(Icons.swap_vert),
                title: 'Loại',
                value: typeLabel),
          ]),
          if (t.note.isNotEmpty)
            InsetSection(
              header: 'Ghi chú',
              children: [InsetRow(title: t.note, wrap: true)],
            ),
          InsetSection(
            footer:
                'MoneyNote chỉ ghi sổ — không tính toán hộ. Số liệu do bạn nhập.',
            children: [
              InsetRow(
                key: const Key('deleteTxn'),
                leading: Icon(Icons.delete, size: 22, color: money.expense),
                title: 'Xoá giao dịch',
                destructive: true,
                onTap: () => _delete(t),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
