import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/features/wallets/wallet_edit_screen.dart';
import 'package:moneynote/features/wallets/wallets_screen.dart';
import 'package:moneynote/state/providers.dart';

/// Read-only wallet detail: a color-tinted header (name · type, balance,
/// Chuyển/Sửa) over the wallet's recent transactions.
class WalletDetailScreen extends ConsumerWidget {
  const WalletDetailScreen(this.walletId, {super.key});

  final String walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    Wallet? found;
    for (final x in wallets) {
      if (x.id == walletId) {
        found = x;
        break;
      }
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ví')),
        body: const Center(child: Text('Ví không tồn tại')),
      );
    }
    final w = found;
    final catById = {for (final c in categories) c.id: c};
    final mine = txns
        .where((t) => t.walletId == w.id || t.toWalletId == w.id)
        .take(15)
        .toList();
    final color = Color(w.color);
    // White text on a dark wallet colour, near-black on a pale one (the palette
    // is all mid-to-dark, but a custom/future light colour stays legible).
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    Widget action(IconData icon, String label, Key key, VoidCallback onTap) =>
        GestureDetector(
          key: key,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: onColor.withAlpha(46), shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: onColor),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(fontSize: 12, color: onColor.withAlpha(230))),
            ],
          ),
        );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            key: const Key('walletDetailHeader'),
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
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
                    child: Column(
                      children: [
                        Text('${w.name} · ${walletTypeLabel(w.type)}',
                            style: TextStyle(
                                fontSize: 14, color: onColor.withAlpha(209))),
                        const SizedBox(height: 6),
                        Text(formatVnd(balanceOf(w, txns)),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              color: onColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            )),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            action(
                                Icons.swap_horiz,
                                'Chuyển',
                                const Key('walletTransfer'),
                                () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => AddTransactionScreen(
                                            initialTransferFromWalletId: w.id)))),
                            const SizedBox(width: 24),
                            action(
                                Icons.tune,
                                'Sửa',
                                const Key('walletEdit'),
                                () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            WalletEditScreen(existing: w)))),
                          ],
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
                    category: catById[t.categoryId],
                    onTap: () => openTransactionDetail(context, t.id),
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
