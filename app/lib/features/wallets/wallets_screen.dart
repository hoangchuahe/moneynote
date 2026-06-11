import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/state/providers.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];

    return Scaffold(
      body: ListView(
        children: [
          for (final w in wallets)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(w.name),
              subtitle: Text(_typeLabel(w.type)),
              trailing: Text(formatVnd(balanceOf(w, txns)),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onLongPress: () =>
                  ref.read(repositoryProvider).softDeleteWallet(w.id),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addWalletDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _typeLabel(WalletType t) => switch (t) {
        WalletType.cash => 'Tiền mặt',
        WalletType.bank => 'Ngân hàng',
        WalletType.ewallet => 'Ví điện tử',
      };

  Future<void> _addWalletDialog(BuildContext context, WidgetRef ref) async {
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Số dư ban đầu'),
              ),
              DropdownButton<WalletType>(
                value: type,
                isExpanded: true,
                items: [
                  for (final t in WalletType.values)
                    DropdownMenuItem(value: t, child: Text(_typeLabel(t))),
                ],
                onChanged: (v) => setState(() => type = v ?? WalletType.cash),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                ref.read(repositoryProvider).addWallet(
                      name: name,
                      type: type,
                      initialBalance: int.tryParse(balCtrl.text.trim()) ?? 0,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
