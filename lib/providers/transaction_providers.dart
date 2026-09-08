import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/transaction_repository.dart';
import '../models/transaction.dart';
import 'auth_providers.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final repo = TransactionRepository();
  repo.initLocal();
  return repo;
});

final transactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final uid = ref.watch(dataUidProvider);
  if (uid == 'signed_out') return Stream.value(const []);
  return ref.watch(transactionRepositoryProvider).watchTransactions(uid);
});

final pendingSyncProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(dataUidProvider);
  if (uid == 'signed_out') return Stream.value(0);
  return ref.watch(transactionRepositoryProvider).watchPendingCount(uid);
});

class Totals {
  const Totals({
    required this.income,
    required this.expense,
    required this.monthIncome,
    required this.monthExpense,
    required this.yearIncome,
    required this.yearExpense,
  });

  final double income;
  final double expense;
  final double monthIncome;
  final double monthExpense;
  final double yearIncome;
  final double yearExpense;

  double get balance => income - expense;
  double get monthBalance => monthIncome - monthExpense;
  double get yearBalance => yearIncome - yearExpense;
}

final totalsProvider = Provider<Totals>((ref) {
  final list = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  double income = 0, expense = 0, mIn = 0, mEx = 0, yIn = 0, yEx = 0;
  for (final t in list) {
    final isIn = t.type == TransactionType.income;
    final isThisMonth =
        t.dateTime.year == now.year && t.dateTime.month == now.month;
    final isThisYear = t.dateTime.year == now.year;
    if (isIn) {
      income += t.amount;
      if (isThisMonth) mIn += t.amount;
      if (isThisYear) yIn += t.amount;
    } else {
      expense += t.amount;
      if (isThisMonth) mEx += t.amount;
      if (isThisYear) yEx += t.amount;
    }
  }
  return Totals(
    income: income,
    expense: expense,
    monthIncome: mIn,
    monthExpense: mEx,
    yearIncome: yIn,
    yearExpense: yEx,
  );
});
