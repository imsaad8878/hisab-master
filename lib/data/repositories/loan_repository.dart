import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/loan.dart';

/// Stores "দাম-পাওনা" (loan) records for a signed-in account, or on the
/// device in demo mode. Same data-safety rules as TransactionRepository:
/// local reads wait for init, corrupt JSON is backed up, and everything
/// merges into Firestore by id on first login.
class LoanRepository {
  LoanRepository();

  static const String _prefsKey = 'hisab_local_loans_v1';
  static const String _backupKey = 'hisab_local_loans_backup_v1';
  static const String _ownerKey = 'hisab_loans_owner_v1';

  static final math.Random _rand = math.Random();

  final StreamController<List<LoanRecord>> _localController =
      StreamController.broadcast();
  List<LoanRecord> _localCache = [];
  Future<void>? _initFuture;
  bool _migrated = false;

  CollectionReference<Map<String, dynamic>> _col(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('loans');

  static List<LoanRecord> _sorted(List<LoanRecord> list) {
    final open = list.where((l) => !l.settled).toList()
      ..sort((a, b) => (b.date ?? DateTime(2000))
          .compareTo(a.date ?? DateTime(2000)));
    final settled = list.where((l) => l.settled).toList()
      ..sort((a, b) => (b.date ?? DateTime(2000))
          .compareTo(a.date ?? DateTime(2000)));
    return [...open, ...settled];
  }

  Future<void> initLocal() => _initFuture ??= _initLocal();

  Future<void> _initLocal() async {
    if (FirebaseService.useLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _localCache = _decodeOrRecover(prefs, raw);
      }
      _localController.add(_sorted(_localCache));
    } catch (_) {}
  }

  List<LoanRecord> _decodeOrRecover(SharedPreferences prefs, String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('not a list');
      final items = <LoanRecord>[];
      for (final m in decoded) {
        if (m is! Map) continue;
        final l = LoanRecord.fromMap(
            (m['id'] as String?) ?? '', m.cast<String, dynamic>());
        if (l.id.isEmpty || l.amount <= 0) continue;
        items.add(l);
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

  Future<void> _persist(SharedPreferences? prefs) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(
        _prefsKey,
        jsonEncode([
          for (final l in _localCache) {'id': l.id, ...l.toMap()},
        ]),
      );
    } catch (_) {}
  }

  Future<void> _emitLocal(List<LoanRecord> next) async {
    _localCache = next;
    _localController.add(_sorted(next));
    await _persist(null);
  }

  Stream<List<LoanRecord>> watchLoans(String uid) async* {
    if (!FirebaseService.useLocal) {
      await initLocal();
      yield _sorted(_localCache);
      yield* _localController.stream.map(_sorted);
      return;
    }
    unawaited(ensureMigratedToCloud(uid));
    yield* _col(uid).snapshots().map((snap) {
      return _sorted([
        for (final doc in snap.docs) LoanRecord.fromMap(doc.id, doc.data()),
      ]);
    });
  }

  Future<void> saveLoan(String uid, LoanRecord l) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      final exists = _localCache.any((x) => x.id == l.id);
      await _emitLocal(exists
          ? [for (final x in _localCache) x.id == l.id ? l : x]
          : [..._localCache, l]);
      return;
    }
    await ensureMigratedToCloud(uid);
    await _col(uid).doc(l.id).set(l.toMap());
  }

  Future<void> deleteLoan(String uid, String id) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      await _emitLocal(_localCache.where((x) => x.id != id).toList());
      return;
    }
    await _col(uid).doc(id).delete();
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
        if (list.isNotEmpty) {
          final existing = await _col(uid).get();
          final seen = {for (final d in existing.docs) d.id};
          for (final m in list) {
            final id = (m['id'] as String?) ?? '';
            if (id.isEmpty || seen.contains(id)) continue;
            final l = LoanRecord.fromMap(id, m);
            if (l.amount <= 0) continue;
            await _col(uid).doc(id).set(l.toMap());
            seen.add(id);
          }
        }
      }
      await prefs.setString(_ownerKey, uid);
    } catch (_) {
      _migrated = false;
    }
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}'
      '-${_rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
