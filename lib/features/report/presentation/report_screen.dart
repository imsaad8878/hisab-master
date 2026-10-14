import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/transaction.dart';
import '../../../providers/transaction_providers.dart';
import '../../../utils/export.dart';
import '../../../utils/format.dart';

enum _Period { month, year, all }

/// Full written report: totals, savings rate, category breakdown,
/// income sources and a month-by-month table. Can be copied as text.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(transactionsProvider).valueOrNull ?? [];
    final theme = Theme.of(context);
    final now = DateTime.now();

    final list = all.where((t) {
      switch (_period) {
        case _Period.month:
          return t.dateTime.year == now.year && t.dateTime.month == now.month;
        case _Period.year:
          return t.dateTime.year == now.year;
        case _Period.all:
          return true;
      }
    }).toList();

    double income = 0, expense = 0;
    final byCategory = <String, double>{};
    final byMonth = <String, List<double>>{}; // month -> [in, out]
    final days = <String>{};
    for (final t in list) {
      final isIn = t.type == TransactionType.income;
      if (isIn) {
        income += t.amount;
      } else {
        expense += t.amount;
        byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      }
      days.add(Format.date(t.dateTime));
      final key =
          '${t.dateTime.year}-${t.dateTime.month.toString().padLeft(2, '0')}';
      final row = byMonth.putIfAbsent(key, () => [0, 0]);
      if (isIn) {
        row[0] += t.amount;
      } else {
        row[1] += t.amount;
      }
    }
    final net = income - expense;
    final savingsRate = income > 0 ? (net / income * 100) : 0.0;
    final topCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    final title = switch (_period) {
      _Period.month => 'Monthly report — ${Format.date(DateTime(now.year, now.month, 1))}',
      _Period.year => 'Yearly report — ${now.year}',
      _Period.all => 'Complete report — all time',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => shareTransactionsPdf(list, title),
          ),
          IconButton(
            tooltip: 'Share CSV (Excel)',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: () => shareTransactionsCsv(list),
          ),
          IconButton(
            tooltip: 'Copy report',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copyReport(
              title, list, income, expense, net, savingsRate, topCats, months, byMonth,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(
                  value: _Period.month,
                  label: Text('This month'),
                  icon: Icon(Icons.calendar_month, size: 16)),
              ButtonSegment(
                  value: _Period.year,
                  label: Text('This year'),
                  icon: Icon(Icons.date_range, size: 16)),
              ButtonSegment(
                  value: _Period.all,
                  label: Text('All time'),
                  icon: Icon(Icons.all_inclusive, size: 16)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${list.length} entries • ${days.length} day(s) covered',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                    label: 'Income',
                    value: Format.tk(income),
                    color: Colors.green[800]!),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                    label: 'Expense',
                    value: Format.tk(expense),
                    color: theme.colorScheme.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Stat(
            label: net >= 0 ? 'Net savings' : 'Net loss',
            value: Format.tk(net),
            color: net >= 0 ? Colors.green[800]! : theme.colorScheme.error,
            big: true,
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Savings rate',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${savingsRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: savingsRate >= 20
                                  ? Colors.green[800]
                                  : theme.colorScheme.error)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (savingsRate.clamp(0, 100)) / 100,
                      minHeight: 10,
                      color: savingsRate >= 20
                          ? Colors.green[700]
                          : theme.colorScheme.error,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    income > 0
                        ? 'Income er ${savingsRate.toStringAsFixed(0)}% '
                            'bachay rekhechen (target: 20%+).'
                        : 'Ei period e kono income show kora nei.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Expense by category',
            empty: 'No expense in this period.',
            children: [
              for (final e in topCats)
                _BreakRow(
                  category: e.key,
                  amount: e.value,
                  percent: expense > 0 ? e.value / expense : 0,
                  color: theme.colorScheme.error,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Month by month',
            empty: 'No data yet.',
            children: [
              for (final m in months)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 74,
                          child: Text(m,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13))),
                      Expanded(
                        child: Text('+${Format.tk(byMonth[m]![0])}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[800],
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text('-${Format.tk(byMonth[m]![1])}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 92,
                        child: Text(
                          Format.tk(byMonth[m]![0] - byMonth[m]![1]),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: byMonth[m]![0] - byMonth[m]![1] >= 0
                                ? Colors.green[800]
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyReport(
    String title,
    List<TransactionModel> list,
    double income,
    double expense,
    double net,
    double savingsRate,
    List<MapEntry<String, double>> topCats,
    List<String> months,
    Map<String, List<double>> byMonth,
  ) async {
    final b = StringBuffer()
      ..writeln('HISAB MASTER — REPORT')
      ..writeln(title)
      ..writeln('Generated: ${Format.date(DateTime.now())} ${Format.time(DateTime.now())}')
      ..writeln('-' * 34)
      ..writeln('Entries: ${list.length}')
      ..writeln('Income:  ${Format.tk(income)}')
      ..writeln('Expense: ${Format.tk(expense)}')
      ..writeln('${net >= 0 ? 'Net savings' : 'Net loss'}: ${Format.tk(net)}')
      ..writeln('Savings rate: ${savingsRate.toStringAsFixed(1)}%');
    if (topCats.isNotEmpty) {
      b
        ..writeln()
        ..writeln('EXPENSE BY CATEGORY');
      for (final e in topCats) {
        b.writeln('  ${e.key}: ${Format.tk(e.value)}');
      }
    }
    if (months.isNotEmpty) {
      b
        ..writeln()
        ..writeln('MONTH BY MONTH  (income / expense / net)');
      for (final m in months) {
        final row = byMonth[m]!;
        b.writeln(
            '  $m: ${Format.tk(row[0])} / ${Format.tk(row[1])} / ${Format.tk(row[0] - row[1])}');
      }
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Row(children: [
        Icon(Icons.copy_all, color: Colors.white, size: 20),
        SizedBox(width: 10),
        Text('Full report copied — paste anywhere to share.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    ));
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      required this.color,
      this.big = false});

  final String label;
  final String value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: big ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.empty, required this.children});

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (children.isEmpty)
              Text(empty, style: TextStyle(color: Colors.grey[600]))
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _BreakRow extends StatelessWidget {
  const _BreakRow(
      {required this.category,
      required this.amount,
      required this.percent,
      required this.color});

  final String category;
  final double amount;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(fontSize: 13.5)),
              Text('${Format.tk(amount)}  (${(percent * 100).toStringAsFixed(0)}%)',
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 7,
              color: color,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
