import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/domain/reports.dart';

/// Trend thu/chi 6 kỳ (gallery ScreenTrend): cột kép thu+chi, kỳ hiện tại (cột
/// cuối) làm đậm nhãn trục. Nhận List<PeriodFlow> nên dùng chung tháng/quý/năm.
class PeriodFlowCard extends StatelessWidget {
  final List<PeriodFlow> flows;
  const PeriodFlowCard({super.key, required this.flows});

  @override
  Widget build(BuildContext context) {
    final hasData = flows.any((f) => f.income > 0 || f.expense > 0);
    if (!hasData) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.bar_chart,
            title: 'Chưa có thu chi nào',
            hint: 'Thêm giao dịch để xem xu hướng',
          ),
        ),
      );
    }
    final money = moneyColorsOf(context);
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final noun = flows.last.period.noun;
    final maxV = flows
        .map((f) => f.income > f.expense ? f.income : f.expense)
        .fold<int>(0, (m, v) => v > m ? v : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Thu / chi · 6 $noun',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                _dot(money.income, 'Thu', muted),
                const SizedBox(width: 12),
                _dot(money.expense, 'Chi', muted),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(BarChartData(
                maxY: maxV * 1.1,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= flows.length) {
                          return const SizedBox.shrink();
                        }
                        final cur = i == flows.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(flows[i].period.shortLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cur ? cs.primary : muted,
                                  fontWeight:
                                      cur ? FontWeight.w600 : FontWeight.w400)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < flows.length; i++)
                    BarChartGroupData(x: i, barsSpace: 3, barRods: [
                      BarChartRodData(
                        toY: flows[i].income.toDouble(),
                        color: money.income,
                        width: 10,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: flows[i].expense.toDouble(),
                        color: money.expense,
                        width: 10,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ]),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color, String label, Color muted) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: muted)),
        ],
      );
}
