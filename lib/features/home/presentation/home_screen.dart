import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart' show kBrandGradient, kBrandText;
import '../../../core/widget/home_widget_helper.dart';
import '../../../models/app_user.dart';
import '../../../models/transaction.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/loan_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/transaction_providers.dart';
import '../../../utils/avatar.dart';
import '../../../utils/format.dart';
import '../../add/presentation/add_transaction_sheet.dart';
import '../../loan/presentation/loan_screen.dart';

enum _Filter { all, income, expense }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _Filter _filter = _Filter.all;
  bool _searchOn = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    registerHomeWidgetUpdates(ref);
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final totals = ref.watch(totalsProvider);
    final user = ref.watch(displayUserProvider);
    final pending = ref.watch(pendingSyncProvider).valueOrNull ?? 0;
    final budget =
        (ref.watch(profileDocProvider).valueOrNull?['monthlyBudget'] as num?)
                ?.toDouble() ??
            0;
    final theme = Theme.of(context);

    final q = _query.trim().toLowerCase();
    final visible = transactions.where((t) {
      final passType = switch (_filter) {
        _Filter.all => true,
        _Filter.income => t.type == TransactionType.income,
        _Filter.expense => t.type == TransactionType.expense,
      };
      if (!passType) return false;
      if (q.isEmpty) return true;
      return t.category.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          t.amount.toStringAsFixed(0).contains(q);
    }).toList();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            user: user,
            totals: totals,
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
            onProfileTap: () =>
                ref.read(navIndexProvider.notifier).state = 3,
          ),
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_sync_outlined,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pending change(s) waiting for internet — data '
                        'safe on this device',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'This Month',
                    icon: Icons.calendar_month,
                    income: totals.monthIncome,
                    expense: totals.monthExpense,
                    net: totals.monthBalance,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'This Year',
                    icon: Icons.auto_awesome,
                    income: totals.yearIncome,
                    expense: totals.yearExpense,
                    net: totals.yearBalance,
                  ),
                ),
              ],
            ),
          ),
          if (budget > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _BudgetCard(
                  budget: budget, spent: totals.monthExpense),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _LoanCard(onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoanScreen()))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('Transactions',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _searchOn = !_searchOn;
                    if (!_searchOn) {
                      _query = '';
                      _searchCtrl.clear();
                    }
                  }),
                  icon: Icon(_searchOn ? Icons.close : Icons.search,
                      size: 20, color: Colors.grey),
                ),
                Text('${visible.length} shown',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          if (_searchOn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search note, category, amount…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No transactions yet',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('Tap "Add" to record your first entry',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
                ],
              ),
            )
          else
            ..._buildGroups(visible),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  List<Widget> _buildGroups(List<TransactionModel> txs) {
    final widgets = <Widget>[];
    String? lastDay;
    var i = 0;
    for (final t in txs) {
      final day = Format.dayLabel(t.dateTime);
      if (day != lastDay) {
        lastDay = day;
        widgets.add(Padding(
          padding: EdgeInsets.fromLTRB(20, i == 0 ? 4 : 16, 20, 8),
          child: Text(day,
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5)),
        ));
      }
      i++;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: _TransactionTile(transaction: t),
      ));
    }
    return widgets;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.totals,
    required this.filter,
    required this.onFilter,
    required this.onProfileTap,
  });

  final AppUser? user;
  final Totals totals;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF146C43).withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        child: Stack(
          children: [
            // glow orbs
            Positioned(
              top: -70,
              right: -50,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF6FE3B0).withValues(alpha: 0.35),
                    const Color(0xFF6FE3B0).withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hisab Master',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                'Assalamu alaikum, '
                                '${user?.displayName?.split(' ').first ?? 'friend'}',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: onProfileTap,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.55),
                                  width: 1.6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6FE3B0)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: userAvatar(user, radius: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text('Available Balance',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      Format.tk(totals.balance),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          height: 1.1,
                          shadows: [
                            Shadow(
                                color: Color(0x55000000),
                                blurRadius: 12,
                                offset: Offset(0, 4)),
                          ]),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _GlassStat(
                            icon: Icons.north_east_rounded,
                            label: 'Income',
                            value: Format.compactTk(totals.income),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GlassStat(
                            icon: Icons.south_west_rounded,
                            label: 'Expense',
                            value: Format.compactTk(totals.expense),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final f in _Filter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: switch (f) {
                                _Filter.all => 'All',
                                _Filter.income => 'Income',
                                _Filter.expense => 'Expense',
                              },
                              selected: filter == f,
                              onTap: () => onFilter(f),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
          const Spacer(),
          Text('৳ $value',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? kBrandText : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String title;
  final IconData icon;
  final double income;
  final double expense;
  final double net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: kBrandText),
                const SizedBox(width: 6),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            _MiniRow(
                icon: Icons.north_east_rounded,
                color: Colors.green[800]!,
                value: Format.tk(income)),
            const SizedBox(height: 4),
            _MiniRow(
                icon: Icons.south_west_rounded,
                color: theme.colorScheme.error,
                value: Format.tk(expense)),
            const Divider(height: 18),
            Text(
              net >= 0 ? '+${Format.tk(net)} saved' : Format.tk(net),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: net >= 0 ? Colors.green[800] : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.spent});

  final double budget;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = (spent / budget).clamp(0.0, 1.0);
    final color = ratio >= 1.0
        ? theme.colorScheme.error
        : ratio >= 0.8
            ? Colors.orange
            : kBrandText;
    final remaining = budget - spent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 16, color: color),
                const SizedBox(width: 6),
                Text('Monthly Budget', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  remaining >= 0
                      ? '${Format.tk(remaining)} left'
                      : '${Format.tk(-remaining)} over',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${Format.tk(spent)} of ${Format.tk(budget)} spent',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanCard extends ConsumerWidget {
  const _LoanCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (given, taken) = ref.watch(loanSummaryProvider);
    final net = given - taken;
    if (given == 0 && taken == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (net >= 0 ? Colors.green : theme.colorScheme.error)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.handshake_outlined,
              color: net >= 0 ? Colors.green[800] : theme.colorScheme.error,
              size: 20),
        ),
        title: const Text('দাম-পাওনা',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          'পাবেন: ${Format.tk(given)}  •  দিবেন: ${Format.tk(taken)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = transaction;
    final theme = Theme.of(context);
    final isIncome = t.type == TransactionType.income;

    Future<void> confirmDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete transaction?'),
          content: Text('${isIncome ? '+' : '-'}${Format.tk(t.amount)}'
              ' (${t.category}) will be removed.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (ok == true) {
        await ref
            .read(transactionRepositoryProvider)
            .deleteTransaction(ref.read(dataUidProvider), t.id);
      }
    }

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await confirmDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onTap: () => showAddTransactionSheet(context, existing: t),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isIncome
                  ? Colors.green.withValues(alpha: 0.12)
                  : theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(categoryIcon(t.category),
                color:
                    isIncome ? Colors.green[800] : theme.colorScheme.onErrorContainer,
                size: 21),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(t.category,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              if (t.photo != null && t.photo!.isNotEmpty)
                GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => Dialog(
                      child: InteractiveViewer(
                        child: Image.memory(
                          base64Decode(t.photo!),
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Photo unavailable'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Icon(Icons.photo_camera_back,
                      size: 15, color: Colors.blueGrey),
                ),
            ],
          ),
          subtitle: Text(
            t.note.isEmpty
                ? '${Format.date(t.dateTime)} • ${Format.time(t.dateTime)}'
                : '${t.note}\n${Format.date(t.dateTime)} • ${Format.time(t.dateTime)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isIncome ? '+${Format.tk(t.amount)}' : '-${Format.tk(t.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isIncome ? Colors.green[800] : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 2),
              Text(Format.time(t.dateTime),
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
