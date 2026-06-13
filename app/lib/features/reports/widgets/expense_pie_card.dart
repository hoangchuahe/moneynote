import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/empty_state.dart';

/// View-model một lát pie: nhãn + màu + tổng (đã resolve khỏi Drift Category).
class CategorySlice {
  final String label;
  final Color color;
  final int total;
  const CategorySlice(
      {required this.label, required this.color, required this.total});
}

class ExpensePieCard extends StatelessWidget {
  final List<CategorySlice> slices;
  const ExpensePieCard({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.pie_chart_outline,
            title: 'Chưa có chi tiêu tháng này',
            hint: 'Thêm giao dịch chi để xem cơ cấu danh mục',
          ),
        ),
      );
    }
    final total = slices.fold<int>(0, (s, e) => s + e.total);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Chi theo danh mục',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                Text(formatVnd(total),
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 34,
                    sections: [
                      for (final s in slices)
                        PieChartSectionData(
                          value: s.total.toDouble(),
                          color: s.color,
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final s in slices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(s.label,
                                      style: const TextStyle(fontSize: 12))),
                              Text(formatVnd(s.total),
                                  style:
                                      TextStyle(fontSize: 11, color: muted)),
                              const SizedBox(width: 8),
                              Text('${(s.total / total * 100).round()}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
