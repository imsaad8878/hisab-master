import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/transaction.dart';

/// Works with Firestore when Firebase is configured; in demo mode it keeps
/// everything on the device using SharedPreferences.
///
/// Data-safety rules:
///  - Every local read/write waits for [initLocal] so an early save can
///    never overwrite the stored list with a half-loaded one.
///  - A corrupt local JSON is copied to a backup key instead of being
///    silently replaced with an empty list.
///  - The first Firebase login migrates on-device demo entries to
///    Firestore, so signing in never looks like the data disappeared.
class TransactionRepository {
  TransactionRepository();

  static const String _prefsKey = 'hisab_local_transactions_v1';
  static const String _backupKey = 'hisab_local_transactions_backup_v1';
  static const String _migratedKey = 'hisab_cloud_migrated_v1';

  static final math.Random _rand = math.Random();

  final StreamController<List<TransactionModel>> _localController =
      StreamController.broadcast();
  List<TransactionModel> _localCache = [];
  Future<void>? _initFuture;
  bool _migrated = false;

  CollectionReference<Map<String, dynamic>> _col(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('transactions');

  static List<TransactionModel> _sorted(List<TransactionModel> list) {
    final sorted = [...list]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return sorted;
  }

  /// Completes once local storage is safe to read and write.
  Future<void> initLocal() => _initFuture ??= _initLocal();

  Future<void> _initLocal() async {
    if (FirebaseService.useLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        _localCache = _seedDemo();
        await _persist(prefs);
      } else {
        _localCache = _decodeOrRecover(prefs, raw);
      }
      _localController.add(_sorted(_localCache));
    } catch (_) {
      // Never let a storage hiccup crash the app; cache stays empty but the
      // raw string is left untouched so nothing is destroyed.
    }
  }

  /// Parses the stored JSON. On corruption the bad payload is moved to a
  /// backup key (for manual recovery) and an empty list is used instead —
  /// the broken string is never overwritten in place.
  List<TransactionModel> _decodeOrRecover(SharedPreferences prefs, String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('not a list');
      final items = <TransactionModel>[];
      for (final m in decoded) {
        if (m is! Map) continue;
        final t = TransactionModel.fromMap(
            (m['id'] as String?) ?? '', m.cast<String, dynamic>());
        if (t.id.isEmpty || t.amount <= 0) continue;
        items.add(t);
      }
      return items;
    } catch (_) {
      scheduleMicrotask(() async {
        try {
          await prefs.setString(_backupKey, raw);
        } catch (_) {}
      });
      return [];
    }
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

  Future<void> _persist(SharedPreferences? prefs) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(
        _prefsKey,
        jsonEncode([
          for (final t in _localCache) {'id': t.id, ...t.toMap()},
        ]),
      );
    } catch (_) {}
  }

  Future<void> _emitLocal(List<TransactionModel> next) async {
    _localCache = next;
    _localController.add(_sorted(next));
    await _persist(null);
  }

  Stream<List<TransactionModel>> watchTransactions(String uid) async* {
    if (!FirebaseService.useLocal) {
      await initLocal();
      yield _sorted(_localCache);
      yield* _localController.stream.map(_sorted);
      return;
    }
    unawaited(ensureMigratedToCloud(uid));
    yield* _col(uid).snapshots().map((snap) {
      return _sorted([
        for (final doc in snap.docs) TransactionModel.fromMap(doc.id, doc.data()),
      ]);
    });
  }

  /// Number of writes still waiting to sync to the server.
  Stream<int> watchPendingCount(String uid) async* {
    if (!FirebaseService.useLocal) {
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
    if (!FirebaseService.useLocal) {
      await initLocal();
      final exists = _localCache.any((x) => x.id == t.id);
      await _emitLocal(exists
          ? [for (final x in _localCache) x.id == t.id ? t : x]
          : [..._localCache, t]);
      return;
    }
    await ensureMigratedToCloud(uid);
    await _col(uid).doc(t.id).set(t.toMap());
  }

  Future<void> updateTransaction(String uid, TransactionModel t) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      await _emitLocal([
        for (final x in _localCache) x.id == t.id ? t : x,
      ]);
      return;
    }
    await _col(uid).doc(t.id).set(t.toMap());
  }

  Future<void> deleteTransaction(String uid, String id) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      await _emitLocal(_localCache.where((x) => x.id != id).toList());
      return;
    }
    await _col(uid).doc(id).delete();
  }

  /// One-time move of on-device demo data into Firestore after the first
  /// Firebase login. Skips if the cloud already has entries, and only marks
  /// itself done after a fully successful run (so a failed attempt retries).
  Future<void> ensureMigratedToCloud(String uid) async {
    if (_migrated) return;
    _migrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migratedKey) ?? false) return;
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          final remote = await _col(uid).get();
          if (remote.docs.isEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            for (final m in list) {
              final id = (m['id'] as String?) ?? '';
              if (id.isEmpty) continue;
              final t = TransactionModel.fromMap(id, m);
              // never push the auto-generated demo samples into a real account
              if (t.amount <= 0 || t.note.startsWith('Demo:')) continue;
              batch.set(_col(uid).doc(id), t.toMap());
            }
            await batch.commit();
          }
        }
      }
      await prefs.setBool(_migratedKey, true);
    } catch (_) {
      _migrated = false; // retry on the next call/session
    }
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}'
      '-${_rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
