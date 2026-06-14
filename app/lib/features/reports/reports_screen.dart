import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/domain/report_period.dart';
import 'package:moneynote/domain/reports.dart';
import 'package:moneynote/features/categories/category_detail_screen.dart';
import 'package:moneynote/features/reports/widgets/category_donut.dart';
import 'package:moneynote/features/reports/widgets/period_flow_card.dart';
import 'package:moneynote/state/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gran = ref.watch(reportGranularityProvider);
    final anchor = ref.watch(selectedMonthProvider);
    final period = ReportPeriod(gran, anchor);
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final cs = Theme.of(context).colorScheme;
    final money = moneyColorsOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (txns) {
          final catById = {for (final c in categories) c.id: c};
          final spends = expenseByCategory(txns, period);
          final sum = spends.fold<int>(0, (s, e) => s + e.total);
          final slices = [
            for (final s in spends)
              CategorySlice(
                label: catById[s.categoryId]?.name ?? 'Chưa phân loại',
                color: Color(catById[s.categoryId]?.color ?? 0xFF9E9E9E),
                total: s.total,
              ),
          ];
          final flows = periodFlow(txns, period, count: 6);
          final hasFlow = flows.any((f) => f.income > 0 || f.expense > 0);
          final peak = flowPeakExpense(flows);
          final nounCap =
              '${period.noun[0].toUpperCase()}${period.noun.substring(1)}';

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SegmentedButton<ReportGranularity>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: ReportGranularity.month, label: Text('Tháng')),
                    ButtonSegment(
                        value: ReportGranularity.quarter, label: Text('Quý')),
                    ButtonSegment(
                        value: ReportGranularity.year, label: Text('Năm')),
                  ],
                  selected: {gran},
                  onSelectionChanged: (s) =>
                      ref.read(reportGranularityProvider.notifier).state =
                          s.first,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const Key('reportsPrevPeriod'),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => ref
                          .read(selectedMonthProvider.notifier)
                          .state = period.prev.start,
                    ),
                    Text(period.label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    IconButton(
                      key: const Key('reportsNextPeriod'),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => ref
                          .read(selectedMonthProvider.notifier)
                          .state = period.next.start,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: CategoryDonut(slices: slices),
              ),
              if (spends.isNotEmpty)
                InsetSection(
                  header: 'Theo danh mục',
                  children: [
                    for (final s in spends)
                      InsetRow(
                        leading: catById[s.categoryId] == null
                            ? const _MutedIconBox()
                            : CategoryIconBox(
                                iconName: catById[s.categoryId]!.icon,
                                color: catById[s.categoryId]!.color),
                        title: catById[s.categoryId]?.name ?? 'Chưa phân loại',
                        value: '${(s.total / sum * 100).round()}%',
                        trailing: Text(formatVnd(s.total),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: money.expense)),
                        onTap: catById[s.categoryId] == null
                            ? null
                            : () => openCategoryDetail(context, s.categoryId!),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: PeriodFlowCard(flows: flows),
              ),
              if (hasFlow)
                InsetSection(
                  children: [
                    InsetRow(
                      leading: Icon(Icons.show_chart,
                          size: 22, color: cs.onSurfaceVariant),
                      title: 'Trung bình / ${period.noun}',
                      value: formatVnd(flowAvgExpense(flows)),
                    ),
                    InsetRow(
                      leading: Icon(Icons.calendar_month,
                          size: 22, color: cs.onSurfaceVariant),
                      title: '$nounCap cao nhất',
                      value: peak == null
                          ? '—'
                          : '${peak.period.shortLabel} · ${formatVnd(peak.expense)}',
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// Leading box for the null (Chưa phân loại) breakdown bucket — a neutral
/// CategoryIconBox-sized square so the row reads as a non-category.
class _MutedIconBox extends StatelessWidget {
  const _MutedIconBox();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.help_outline, size: 18, color: cs.onSurfaceVariant),
    );
  }
}
