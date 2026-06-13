import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';
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

/// The 6 wallet swatches from the design's add-wallet color picker.
const kWalletColors = <int>[
  0xFF0B7A4F, 0xFF2A6FDB, 0xFFD97A4A, 0xFF9B5DE5, 0xFFE0457B, 0xFF1F8A70,
];

/// Tinted box for a wallet: the type glyph in the wallet's color.
class WalletIconBox extends StatelessWidget {
  const WalletIconBox({
    super.key,
    required this.color,
    required this.type,
    this.size = 36,
  });

  final int color;
  final WalletType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withAlpha(36),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(walletTypeIcon(type), size: size * 0.5, color: c),
    );
  }
}

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
      padding: EdgeInsets.only(bottom: pillClearance(context)),
      children: [
        for (final w in wallets)
          ListTile(
            leading: WalletIconBox(color: w.color, type: w.type),
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

