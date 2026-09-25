import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../utils/formatters.dart';

class ChartSeries {
  const ChartSeries({
    required this.points,
    required this.color,
    this.label = '',
    this.dashed = false,
    this.showDots = true,
  });

  /// Oldest first.
  final List<({DateTime date, double value})> points;
  final Color color;
  final String label;
  final bool dashed;
  final bool showDots;
}

/// Date-based line chart used for body weight and exercise trends.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.series,
    this.height = 200,
    this.valueFormat,
  });

  final List<ChartSeries> series;
  final double height;
  final String Function(double value)? valueFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    final all = [for (final s in series) ...s.points];
    if (all.length < 2) {
      return SizedBox(
        height: height / 2,
        child: Center(
          child: Text('trend.needTwo'.tr(), style: theme.textTheme.bodySmall),
        ),
      );
    }

    final origin = all
        .map((p) => p.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    double x(DateTime d) => d.difference(origin).inHours / 24;
    final values = all.map((p) => p.value);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(0.5, double.infinity);
    final maxX = all.map((p) => x(p.date)).reduce((a, b) => a > b ? a : b);
    final format = valueFormat ?? Formatters.weight;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          minX: 0,
          maxX: maxX <= 0 ? 1 : maxX,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.dividerColor, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    format(double.parse(value.toStringAsFixed(1))),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxX <= 0 ? 1 : (maxX / 3).clamp(1, double.infinity),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    Formatters.shortDate(
                      origin.add(Duration(hours: (value * 24).round())),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => context.semanticColors.elevated,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    format(spot.y),
                    TextStyle(color: series[spot.barIndex].color),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            for (final s in series)
              LineChartBarData(
                spots: [for (final p in s.points) FlSpot(x(p.date), p.value)],
                color: s.color,
                barWidth: s.dashed ? 2 : 3,
                isCurved: true,
                preventCurveOverShooting: true,
                dashArray: s.dashed ? const [6, 4] : null,
                dotData: FlDotData(show: s.showDots && s.points.length < 30),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small legend row for [TrendChart].
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.series});

  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      children: [
        for (final s in series.where((s) => s.label.isNotEmpty))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 3, color: s.color),
              const SizedBox(width: AppSpacing.xs),
              Text(s.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
