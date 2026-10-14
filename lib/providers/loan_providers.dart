import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/loan_repository.dart';
import '../data/repositories/recurring_repository.dart';
import '../models/loan.dart';
import 'auth_providers.dart';
import 'transaction_providers.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final repo = LoanRepository();
  repo.initLocal();
  return repo;
});

final loansProvider = StreamProvider<List<LoanRecord>>((ref) {
  final uid = ref.watch(dataUidProvider);
  if (uid == 'signed_out') return Stream.value(const []);
  return ref.watch(loanRepositoryProvider).watchLoans(uid);
});

/// You will get this much (others owe you) minus what you owe.
final loanSummaryProvider = Provider<(double, double)>((ref) {
  final loans = ref.watch(loansProvider).valueOrNull ?? const [];
  double given = 0, taken = 0;
  for (final l in loans.where((l) => !l.settled)) {
    if (l.given) {
      given += l.amount;
    } else {
      taken += l.amount;
    }
  }
  return (given, taken);
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(transactionRepositoryProvider));
});

final recurringRulesProvider = StreamProvider<List<RecurringRule>>((ref) {
  final uid = ref.watch(dataUidProvider);
  if (uid == 'signed_out') return Stream.value(const []);
  return ref.watch(recurringRepositoryProvider).watchRules(uid);
});

/// Creates any missing monthly entries for existing rules (runs once per
/// app session, as soon as rules are known).
final recurringSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(dataUidProvider);
  final rules = ref.watch(recurringRulesProvider).valueOrNull;
  if (uid == 'signed_out' || rules == null) return;
  ref.read(recurringRepositoryProvider).generateDueEntries(uid, rules);
});
