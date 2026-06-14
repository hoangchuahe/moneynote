import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/domain/report_period.dart';
import 'package:moneynote/domain/reports.dart';
import 'package:moneynote/features/reports/widgets/expense_pie_card.dart';
import 'package:moneynote/features/reports/widgets/monthly_flow_card.dart';
import 'package:moneynote/state/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (txns) {
          final catById = {for (final c in categories) c.id: c};
          final slices = [
            for (final s in expenseByCategory(txns, ReportPeriod.month(month)))
              CategorySlice(
                label: catById[s.categoryId]?.name ?? 'Chưa phân loại',
                color: Color(catById[s.categoryId]?.color ?? 0xFF9E9E9E),
                total: s.total,
              ),
          ];
          final flows = monthlyFlow(txns, month, months: 6);
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const Key('reportsPrevMonth'),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => ref
                          .read(selectedMonthProvider.notifier)
                          .state = DateTime(month.year, month.month - 1, 1),
                    ),
                    Text('Tháng ${month.month}/${month.year}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    IconButton(
                      key: const Key('reportsNextMonth'),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => ref
                          .read(selectedMonthProvider.notifier)
                          .state = DateTime(month.year, month.month + 1, 1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ExpensePieCard(slices: slices),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: MonthlyFlowCard(flows: flows),
              ),
            ],
          );
        },
      ),
    );
  }
}
