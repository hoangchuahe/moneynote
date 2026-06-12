import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/state/providers.dart';

String walletTypeLabel(WalletType t) => switch (t) {
      WalletType.cash => 'Tiền mặt',
      WalletType.bank => 'Ngân hàng',
      WalletType.ewallet => 'Ví điện tử',
    };

IconData walletTypeIcon(WalletType t) => switch (t) {
      WalletType.cash => Icons.payments,
      WalletType.bank => Icons.account_balance,
      WalletType.ewallet => Icons.smartphone,
    };

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    if (wallets.isEmpty) {
      return const EmptyState(
          icon: Icons.account_balance_wallet,
          title: 'Chưa có ví nào',
          hint: 'Bấm Thêm ví để tạo ví đầu tiên');
    }
    return ListView(
      children: [
        for (final w in wallets)
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(walletTypeIcon(w.type),
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            title: Text(w.name),
            subtitle: Text(walletTypeLabel(w.type)),
            trailing: Text(formatVnd(balanceOf(w, txns)),
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()])),
            onLongPress: () => _confirmDelete(context, ref, w),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Wallet w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá ví "${w.name}"?'),
        content: const Text('Các giao dịch của ví này cũng sẽ bị xoá.'),
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
      await ref.read(repositoryProvider).softDeleteWallet(w.id);
    }
  }
}

Future<void> showAddWalletDialog(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final balCtrl = TextEditingController(text: '0');
  var type = WalletType.cash;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Thêm ví'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên ví')),
            TextField(
              controller: balCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: const InputDecoration(labelText: 'Số dư ban đầu'),
            ),
            DropdownButton<WalletType>(
              value: type,
              isExpanded: true,
              items: [
                for (final t in WalletType.values)
                  DropdownMenuItem(value: t, child: Text(walletTypeLabel(t))),
              ],
              onChanged: (v) => setState(() => type = v ?? WalletType.cash),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              ref.read(repositoryProvider).addWallet(
                    name: name,
                    type: type,
                    initialBalance: parseVndInput(balCtrl.text),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
  nameCtrl.dispose();
  balCtrl.dispose();
}
