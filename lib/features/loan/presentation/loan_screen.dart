import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/loan_repository.dart';
import '../../../models/loan.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/loan_providers.dart';
import '../../../utils/format.dart';

class LoanScreen extends ConsumerWidget {
  const LoanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(loansProvider).valueOrNull ?? const [];
    final (given, taken) = ref.watch(loanSummaryProvider);
    final net = given - taken;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('দাম-পাওনা (Loans)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _SumCard(
                  label: 'পাবেন (others owe you)',
                  amount: given,
                  color: Colors.green[800]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SumCard(
                  label: 'দিবেন (you owe)',
                  amount: taken,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              dense: true,
              leading: Icon(
                net >= 0 ? Icons.trending_up : Icons.trending_down,
                color: net >= 0 ? Colors.green[800] : theme.colorScheme.error,
              ),
              title: Text(
                net >= 0
                    ? 'Net: +${Format.tk(net)} পাবেন'
                    : 'Net: -${Format.tk(-net)} দিবেন',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: net >= 0 ? Colors.green[800] : theme.colorScheme.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (loans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.handshake_outlined,
                      size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No loan records',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('কার কাছে পাইছো/দিছো — এখানে রাখো',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12.5)),
                ],
              ),
            )
          else
            ...loans.map((l) => _LoanTile(loan: l)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  static Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var given = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('নতুন দাম-পাওনা'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: personCtrl,
                decoration: const InputDecoration(
                    labelText: 'নাম (person name)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Amount (৳)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)', isDense: true),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('দিয়েছি')),
                  ButtonSegment(value: false, label: Text('নিয়েছি')),
                ],
                selected: {given},
                onSelectionChanged: (s) => setDialog(() => given = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final person = personCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (person.isEmpty || amount <= 0) return;
                Navigator.pop(ctx);
                ref.read(loanRepositoryProvider).saveLoan(
                      ref.read(dataUidProvider),
                      LoanRecord(
                        id: LoanRepository.newId(),
                        person: person,
                        amount: amount,
                        given: given,
                        date: DateTime.now(),
                        note: noteCtrl.text.trim(),
                      ),
                    );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  const _SumCard(
      {required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(Format.tk(amount),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _LoanTile extends ConsumerWidget {
  const _LoanTile({required this.loan});

  final LoanRecord loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Delete loan of ${loan.person}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) {
            await ref
                .read(loanRepositoryProvider)
                .deleteLoan(ref.read(dataUidProvider), loan.id);
          }
        },
        leading: CircleAvatar(
          backgroundColor: loan.given
              ? Colors.green.withValues(alpha: 0.14)
              : theme.colorScheme.errorContainer,
          child: Text(
            loan.person.isEmpty ? '?' : loan.person.characters.first.toUpperCase(),
            style: TextStyle(
              color: loan.given ? Colors.green[800] : theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          loan.person,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            decoration: loan.settled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [
            if (loan.date != null) DateFormat('d MMM yyyy').format(loan.date!),
            if (loan.note.isNotEmpty) loan.note,
          ].join(' • '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              loan.settled
                  ? 'Settled ✓'
                  : loan.given
                      ? '+${Format.tk(loan.amount)}'
                      : '-${Format.tk(loan.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: loan.settled
                    ? Colors.grey
                    : loan.given
                        ? Colors.green[800]
                        : theme.colorScheme.error,
              ),
            ),
            if (!loan.settled)
              GestureDetector(
                onTap: () => ref.read(loanRepositoryProvider).saveLoan(
                      ref.read(dataUidProvider),
                      LoanRecord(
                        id: loan.id,
                        person: loan.person,
                        amount: loan.amount,
                        given: loan.given,
                        date: loan.date,
                        note: loan.note,
                        settled: true,
                      ),
                    ),
                child: Text('Mark settled',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
