import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/transaction.dart';

/// Works with Firestore when Firebase is configured; in demo mode it keeps
/// everything on the device using SharedPreferences.
class TransactionRepository {
  TransactionRepository();

  static const String _prefsKey = 'hisab_local_transactions_v1';

  final StreamController<List<TransactionModel>> _localController =
      StreamController.broadcast();
  List<TransactionModel> _localCache = [];

  CollectionReference<Map<String, dynamic>> _col(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('transactions');

  static List<TransactionModel> _sorted(List<TransactionModel> list) {
    final sorted = [...list]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return sorted;
  }

  Future<void> initLocal() async {
    if (FirebaseService.ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        _localCache = _seedDemo();
        await _persist();
      } else {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _localCache = [
          for (final m in list) TransactionModel.fromMap(m['id'] as String, m),
        ];
      }
      _localController.add(_localCache);
    } catch (_) {}
  }

  List<TransactionModel> _seedDemo() {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: newId(),
        amount: 25000,
        type: TransactionType.income,
        category: 'Salary',
        dateTime: DateTime(now.year, now.month, 1, 9),
        note: 'Demo: this month salary',
      ),
      TransactionModel(
        id: newId(),
        amount: 320,
        type: TransactionType.expense,
        category: 'Food',
        dateTime: now.subtract(const Duration(hours: 3)),
        note: 'Demo: biryani with friends',
      ),
      TransactionModel(
        id: newId(),
        amount: 1500,
        type: TransactionType.expense,
        category: 'Transport',
        dateTime: now.subtract(const Duration(days: 2)),
        note: 'Demo: bus + CNG',
      ),
    ];
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([
        for (final t in _localCache) {'id': t.id, ...t.toMap()},
      ]),
    );
  }

  Future<void> _emitLocal(List<TransactionModel> next) async {
    _localCache = next;
    _localController.add(next);
    await _persist();
  }

  Stream<List<TransactionModel>> watchTransactions(String uid) async* {
    if (!FirebaseService.ready) {
      yield _sorted(_localCache);
      yield* _localController.stream.map(_sorted);
      return;
    }
    yield* _col(uid).snapshots().map((snap) {
      return _sorted([
        for (final doc in snap.docs) TransactionModel.fromMap(doc.id, doc.data()),
      ]);
    });
  }

  /// Number of writes still waiting to sync to the server.
  Stream<int> watchPendingCount(String uid) async* {
    if (!FirebaseService.ready) {
      yield 0;
      return;
    }
    yield* _col(uid).snapshots().map((snap) {
      var n = 0;
      for (final d in snap.docs) {
        if (d.metadata.hasPendingWrites) n++;
      }
      return n;
    });
  }

  Future<void> addTransaction(String uid, TransactionModel t) async {
    if (!FirebaseService.ready) {
      await _emitLocal([..._localCache, t]);
      return;
    }
    await _col(uid).doc(t.id).set(t.toMap());
  }

  Future<void> updateTransaction(String uid, TransactionModel t) async {
    if (!FirebaseService.ready) {
      await _emitLocal([
        for (final x in _localCache) x.id == t.id ? t : x,
      ]);
      return;
    }
    await _col(uid).doc(t.id).set(t.toMap());
  }

  Future<void> deleteTransaction(String uid, String id) async {
    if (!FirebaseService.ready) {
      await _emitLocal(_localCache.where((x) => x.id != id).toList());
      return;
    }
    await _col(uid).doc(id).delete();
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${(DateTime.now().microsecondsSinceEpoch ~/ 1000) % 99999}';
}
