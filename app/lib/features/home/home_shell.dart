import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/widgets/large_title_header.dart';
import 'package:moneynote/features/categories/categories_screen.dart';
import 'package:moneynote/features/categories/category_edit_screen.dart';
import 'package:moneynote/features/dashboard/dashboard_screen.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';
import 'package:moneynote/features/reports/reports_screen.dart';
import 'package:moneynote/features/settings/settings_screen.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transactions_list_screen.dart';
import 'package:moneynote/features/wallets/wallet_edit_screen.dart';
import 'package:moneynote/features/wallets/wallets_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['Tổng quan', 'Giao dịch', 'Ví', 'Danh mục'];
  static const _pages = [
    DashboardScreen(),
    TransactionsListScreen(),
    WalletsScreen(),
    CategoriesScreen(),
  ];

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  List<Widget> _actionsFor(int i) => [
        if (i == 0)
          IconButton(
            key: const Key('openReports'),
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Báo cáo',
            onPressed: () => _push(const ReportsScreen()),
          ),
        if (i == 2)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Thêm ví',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletEditScreen())),
          ),
        if (i == 3)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Thêm danh mục',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoryEditScreen())),
          ),
        IconButton(
          key: const Key('openSettings'),
          icon: const Icon(Icons.settings),
          tooltip: 'Cài đặt',
          onPressed: () => _push(const SettingsScreen()),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                LargeTitleHeader(
                  title: _titles[_index],
                  actions: _actionsFor(_index),
                ),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IndexedStack(index: _index, children: _pages),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: pillBottomOffset(context),
                        child: Center(
                          child: FloatingPillNav(
                            selectedIndex: _index,
                            onSelect: (n) => setState(() => _index = n),
                            onAdd: () => _push(const AddTransactionScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
