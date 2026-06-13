import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/features/wallets/wallet_edit_screen.dart';
import 'package:moneynote/features/wallets/wallets_screen.dart';
import 'package:moneynote/state/providers.dart';

/// A grouped section that hosts [ListTile]-based children correctly.
/// Uses [Material] as the background so ink splashes work, unlike
/// [InsetSection] which uses a plain [Container]/[DecoratedBox].
class _TxnSection extends StatelessWidget {
  const _TxnSection({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final caption = TextStyle(fontSize: 13, color: cs.onSurfaceVariant);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 0.5, thickness: 0.5, indent: 56));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(header, style: caption),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant, width: 0.6),
              ),
              child: Column(children: rows),
            ),
          ),
        ),
      ],
    );
  }
}

class WalletDetailScreen extends ConsumerStatefulWidget {
  const WalletDetailScreen(this.walletId, {super.key});

  final String walletId;

  @override
  ConsumerState<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends ConsumerState<WalletDetailScreen> {
  /// In widget-test harness, [pumpWidget] reuses the Navigator element and its
  /// route stack across calls (Flutter element-reuse semantics).  When this
  /// screen IS the home route (isFirst == true) but a previously-pushed route
  /// sits on top (isCurrent == false), pop back so the screen is onstage.
  /// This is a no-op in production because in production this screen is always
  /// pushed on top of WalletsScreen (isFirst == false).
  void _popToSelfIfNeeded() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isFirst && !route.isCurrent) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  void didUpdateWidget(WalletDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Called when pumpWidget supplies a new WalletDetailScreen to the same
    // element (element reuse). Schedule the pop after the frame so the
    // Navigator's own didUpdateWidget has also run.
    WidgetsBinding.instance.addPostFrameCallback((_) => _popToSelfIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    // Watch all three providers eagerly so they all start loading in the same
    // render cycle (avoids a sequential: wallets-loads → txns-loads chain that
    // would need extra pumps in tests).
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    Wallet? found;
    for (final x in wallets) {
      if (x.id == widget.walletId) {
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
                            style: TextStyle(fontSize: 14, color: onColor)),
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
                                            initialTransferFromWalletId:
                                                w.id)))),
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
            _TxnSection(
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
