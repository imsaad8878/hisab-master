import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/loan.dart';
import '../../models/transaction.dart';
import 'transaction_repository.dart';

/// Monthly recurring entries (rent, salary…). Rules live at
/// users/{uid}/recurring; generated transactions keep a stable id
/// (rec_{ruleId}_{yyyy-mm}) so re-running the generator never duplicates.
class RecurringRepository {
  RecurringRepository(this._txRepo);

  final TransactionRepository _txRepo;

  static const String _prefsKey = 'hisab_local_recurring_v1';
  static const String _backupKey = 'hisab_local_recurring_backup_v1';
  static const String _ownerKey = 'hisab_recurring_owner_v1';

  final StreamController<List<RecurringRule>> _localController =
      StreamController.broadcast();
  List<RecurringRule> _localCache = [];
  Future<void>? _initFuture;
  bool _migrated = false;

  CollectionReference<Map<String, dynamic>> _col(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('recurring');

  Future<void> initLocal() => _initFuture ??= _initLocal();

  Future<void> _initLocal() async {
    if (FirebaseService.useLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! List) throw const FormatException('not a list');
          _localCache = [
            for (final m in decoded)
              if (m is Map)
                RecurringRule.fromMap(
                    (m['id'] as String?) ?? '', m.cast<String, dynamic>())
          ].where((r) => r.id.isNotEmpty).toList();
        } catch (_) {
          try {
            await prefs.setString(_backupKey, raw);
          } catch (_) {}
        }
      }
      _localController.add(List.of(_localCache));
    } catch (_) {}
  }

  Stream<List<RecurringRule>> watchRules(String uid) async* {
    if (!FirebaseService.useLocal) {
      await initLocal();
      yield List.of(_localCache);
      yield* _localController.stream;
      return;
    }
    unawaited(ensureMigratedToCloud(uid));
    yield* _col(uid).snapshots().map((snap) => [
          for (final doc in snap.docs)
            RecurringRule.fromMap(doc.id, doc.data())
        ]);
  }

  Future<void> saveRule(String uid, RecurringRule r) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      final exists = _localCache.any((x) => x.id == r.id);
      _localCache = exists
          ? [for (final x in _localCache) x.id == r.id ? r : x]
          : [..._localCache, r];
      _localController.add(List.of(_localCache));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode([
          for (final x in _localCache) {'id': x.id, ...x.toMap()},
        ]));
      } catch (_) {}
      return;
    }
    await ensureMigratedToCloud(uid);
    await _col(uid).doc(r.id).set(r.toMap());
  }

  Future<void> deleteRule(String uid, String id) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      _localCache = _localCache.where((x) => x.id != id).toList();
      _localController.add(List.of(_localCache));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode([
          for (final x in _localCache) {'id': x.id, ...x.toMap()},
        ]));
      } catch (_) {}
      return;
    }
    await _col(uid).doc(id).delete();
  }

  /// Creates missing monthly entries for the last [monthsBack] months and
  /// the current one. Ids are deterministic, so this is safe to call on
  /// every session start.
  Future<void> generateDueEntries(String uid, List<RecurringRule> rules,
      {int monthsBack = 2}) async {
    if (rules.isEmpty) return;
    final now = DateTime.now();
    try {
      for (final rule in rules) {
        final type = rule.type == 'income'
            ? TransactionType.income
            : TransactionType.expense;
        for (var i = monthsBack; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i, 1);
          final day = rule.dayOfMonth > 28 ? 28 : rule.dayOfMonth;
          final when = DateTime(month.year, month.month, day, 10);
          if (when.isAfter(now)) continue;
          final id = 'rec_${rule.id}_${when.year}-${when.month}';
          final exists = await _txRepo.exists(uid, id);
          if (exists) continue;
          await _txRepo.addTransaction(
            uid,
            TransactionModel(
              id: id,
              amount: rule.amount,
              type: type,
              category: rule.category,
              dateTime: when,
              note: rule.note.isEmpty
                  ? 'Auto: ${rule.category} (monthly)'
                  : 'Auto: ${rule.note}',
              recurringId: rule.id,
            ),
          );
        }
      }
    } catch (_) {
      // Offline / permission hiccups are retried next session.
    }
  }

  Future<void> ensureMigratedToCloud(String uid) async {
    if (_migrated) return;
    _migrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final owner = prefs.getString(_ownerKey);
      if (owner != null && owner != uid) return;
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final m in list) {
          final id = (m['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          final r = RecurringRule.fromMap(id, m);
          await _col(uid).doc(id).set(r.toMap());
        }
      }
      await prefs.setString(_ownerKey, uid);
    } catch (_) {
      _migrated = false;
    }
  }
}
