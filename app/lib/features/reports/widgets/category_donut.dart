import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/empty_state.dart';

/// View-model một lát donut: nhãn + màu + tổng (đã resolve khỏi Drift Category).
class CategorySlice {
  final String label;
  final Color color;
  final int total;
  const CategorySlice(
      {required this.label, required this.color, required this.total});
}

/// Donut chi-theo-danh-mục (gallery ScreenReports): vòng nhiều cung trên track
/// xám, tâm hiện "Tổng chi" + tổng. Trình bày thuần — không Riverpod/domain.
class CategoryDonut extends StatelessWidget {
  final List<CategorySlice> slices;
  const CategoryDonut({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.pie_chart_outline,
            title: 'Chưa có chi tiêu kỳ này',
            hint: 'Thêm giao dịch chi để xem cơ cấu danh mục',
          ),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final total = slices.fold<int>(0, (s, e) => s + e.total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 176,
            height: 176,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 58,
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(
                        value: s.total.toDouble(),
                        color: s.color,
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                )),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tổng chi',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(formatVnd(total),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
