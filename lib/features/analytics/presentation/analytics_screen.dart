import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/transaction.dart';
import '../../../providers/transaction_providers.dart';
import '../../../utils/format.dart';

String _monthLabel(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final theme = Theme.of(context);

    final years = <int>{
      DateTime.now().year,
      ...transactions.map((t) => t.dateTime.year),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final monthly = <String, List<TransactionModel>>{};
    for (final t in transactions.where((t) => t.dateTime.year == _selectedYear)) {
      monthly.putIfAbsent(_monthLabel(t.dateTime), () => []).add(t);
    }

    final bars = <BarChartGroupData>[
      for (var m = 1; m <= 12; m++)
        BarChartGroupData(
          x: m,
          barRods: [
            BarChartRodData(
              toY: monthly[_monthLabel(DateTime(_selectedYear, m))]
                  ?.where((t) => t.type == TransactionType.income)
                  .fold<double>(0, (s, t) => s + t.amount) ?? 0,
              color: const Color(0xFF2E7D32),
              width: 8,
              borderRadius: BorderRadius.circular(3),
            ),
            BarChartRodData(
              toY: monthly[_monthLabel(DateTime(_selectedYear, m))]
                  ?.where((t) => t.type == TransactionType.expense)
                  .fold<double>(0, (s, t) => s + t.amount) ?? 0,
              color: theme.colorScheme.error,
              width: 8,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
    ];

    final yearAll = transactions.where((t) => t.dateTime.year == _selectedYear).toList();
    final totalIn = yearAll.where((t) => t.type == TransactionType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    final totalOut = yearAll.where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);

    final byCategory = <String, double>{};
    for (final t in yearAll.where((t) => t.type == TransactionType.expense)) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final topCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (y) => setState(() => _selectedYear = y!),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Income $_selectedYear',
                  value: Format.tk(totalIn),
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Expense $_selectedYear',
                  value: Format.tk(totalOut),
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Income vs Expense', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: () {
                          double max = 1;
                          for (final g in bars) {
                            for (final r in g.barRods) {
                              if (r.toY > max) max = r.toY;
                            }
                          }
                          return max * 1.2;
                        }(),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => const FlLine(
                              color: Colors.black12, strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (v, meta) => Text(
                                Format.compactTk(v),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (v, meta) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _months[(v.toInt() - 1) % 12],
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                        barGroups: bars,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                              '${_months[(group.x - 1) % 12]}\n${Format.tk(rod.toY)}',
                              const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _Dot(color: Color(0xFF2E7D32), label: 'Income'),
                      SizedBox(width: 16),
                      _Dot(color: Color(0xFFC62828), label: 'Expense'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expense by Category', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (topCats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No expense data yet.'),
                    )
                  else
                    for (final e in topCats)
                      _CategoryBar(
                        category: e.key,
                        amount: e.value,
                        maxAmount: topCats.first.value,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.amount, required this.maxAmount});

  final String category;
  final double amount;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(fontSize: 13)),
              Text(Format.tk(amount), style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: amount / maxAmount,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
