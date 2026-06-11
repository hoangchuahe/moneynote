import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/features/categories/categories_screen.dart';
import 'package:moneynote/features/dashboard/dashboard_screen.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transactions_list_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      floatingActionButton: _index <= 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Giao dịch'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'Ví'),
          NavigationDestination(
              icon: Icon(Icons.category), label: 'Danh mục'),
        ],
      ),
    );
  }
}
