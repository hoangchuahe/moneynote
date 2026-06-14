/// The granularity of a reporting window.
enum ReportGranularity { month, quarter, year }

/// A reporting window (month, quarter, or year) identified by its [granularity]
/// and any [anchor] instant inside it. `start`/`end` normalise the anchor to the
/// granularity's calendar bounds (end exclusive), so the same anchor re-read at a
/// different granularity snaps correctly. Pure — no Flutter/Riverpod deps.
class ReportPeriod {
  final ReportGranularity granularity;
  final DateTime anchor;
  const ReportPeriod(this.granularity, this.anchor);
  ReportPeriod.month(DateTime d) : this(ReportGranularity.month, d);
  ReportPeriod.quarter(DateTime d) : this(ReportGranularity.quarter, d);
  ReportPeriod.year(DateTime d) : this(ReportGranularity.year, d);

  DateTime get start => switch (granularity) {
        ReportGranularity.month => DateTime(anchor.year, anchor.month, 1),
        ReportGranularity.quarter =>
          DateTime(anchor.year, ((anchor.month - 1) ~/ 3) * 3 + 1, 1), // 1/4/7/10
        ReportGranularity.year => DateTime(anchor.year, 1, 1),
      };

  /// Exclusive upper bound. `DateTime` normalises month overflow (e.g. month 13).
  DateTime get end => switch (granularity) {
        ReportGranularity.month => DateTime(start.year, start.month + 1, 1),
        ReportGranularity.quarter => DateTime(start.year, start.month + 3, 1),
        ReportGranularity.year => DateTime(start.year + 1, 1, 1),
      };

  bool contains(DateTime when) => !when.isBefore(start) && when.isBefore(end);

  ReportPeriod get prev => switch (granularity) {
        ReportGranularity.month =>
          ReportPeriod(granularity, DateTime(start.year, start.month - 1, 1)),
        ReportGranularity.quarter =>
          ReportPeriod(granularity, DateTime(start.year, start.month - 3, 1)),
        ReportGranularity.year =>
          ReportPeriod(granularity, DateTime(start.year - 1, 1, 1)),
      };

  ReportPeriod get next => ReportPeriod(granularity, end); // end = next start

  int get _q => (start.month - 1) ~/ 3 + 1;

  String get label => switch (granularity) {
        ReportGranularity.month => 'Tháng ${start.month}/${start.year}',
        ReportGranularity.quarter => 'Quý $_q/${start.year}',
        ReportGranularity.year => 'Năm ${start.year}',
      };

  String get shortLabel => switch (granularity) {
        ReportGranularity.month => 'T${start.month}',
        ReportGranularity.quarter => 'Q$_q',
        ReportGranularity.year => '${start.year}',
      };

  String get noun => switch (granularity) {
        ReportGranularity.month => 'tháng',
        ReportGranularity.quarter => 'quý',
        ReportGranularity.year => 'năm',
      };

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.granularity == granularity &&
      other.start == start;

  @override
  int get hashCode => Object.hash(granularity, start);
}
