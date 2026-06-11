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
  static const _fabLabels = ['Thêm', 'Thêm', 'Thêm ví', 'Thêm danh mục'];
  static const _pages = [
    DashboardScreen(),
    TransactionsListScreen(),
    WalletsScreen(),
    CategoriesScreen(),
  ];

  void _onAdd() {
    switch (_index) {
      case 2:
        showAddWalletDialog(context, ref);
      case 3:
        showAddCategoryDialog(context, ref);
      default:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAdd,
        icon: const Icon(Icons.add),
        label: Text(_fabLabels[_index]),
      ),
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
