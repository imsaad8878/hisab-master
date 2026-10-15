import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/note.dart';

/// Personal notes — a small notepad inside the app. Same safety pattern
/// as the other repositories: local-first in demo mode, cloud with
/// Firestore, merge-by-id on first login, corrupt JSON backed up.
class NoteRepository {
  NoteRepository();

  static const String _prefsKey = 'hisab_local_notes_v1';
  static const String _backupKey = 'hisab_local_notes_backup_v1';
  static const String _ownerKey = 'hisab_notes_owner_v1';

  static final math.Random _rand = math.Random();

  final StreamController<List<NoteModel>> _localController =
      StreamController.broadcast();
  List<NoteModel> _localCache = [];
  Future<void>? _initFuture;
  bool _migrated = false;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes');

  static List<NoteModel> _sorted(List<NoteModel> list) =>
      [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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
                NoteModel.fromMap(
                    (m['id'] as String?) ?? '', m.cast<String, dynamic>())
          ].where((n) => n.id.isNotEmpty).toList();
        } catch (_) {
          try {
            await prefs.setString(_backupKey, raw);
          } catch (_) {}
        }
      }
      _localController.add(_sorted(_localCache));
    } catch (_) {}
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode([
        for (final n in _localCache) {'id': n.id, ...n.toMap()},
      ]));
    } catch (_) {}
  }

  Stream<List<NoteModel>> watchNotes(String uid) async* {
    if (!FirebaseService.useLocal) {
      await initLocal();
      yield _sorted(_localCache);
      yield* _localController.stream.map(_sorted);
      return;
    }
    unawaited(ensureMigratedToCloud(uid));
    yield* _col(uid).snapshots().map((snap) => _sorted([
          for (final doc in snap.docs) NoteModel.fromMap(doc.id, doc.data()),
        ]));
  }

  Future<void> saveNote(String uid, NoteModel n) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      final exists = _localCache.any((x) => x.id == n.id);
      _localCache = exists
          ? [for (final x in _localCache) x.id == n.id ? n : x]
          : [..._localCache, n];
      _localController.add(_sorted(_localCache));
      await _persistLocal();
      return;
    }
    await ensureMigratedToCloud(uid);
    await _col(uid).doc(n.id).set(n.toMap());
  }

  Future<void> deleteNote(String uid, String id) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      _localCache = _localCache.where((x) => x.id != id).toList();
      _localController.add(_sorted(_localCache));
      await _persistLocal();
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
        for (final m in list) {
          final id = (m['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          final n = NoteModel.fromMap(id, m);
          await _col(uid).doc(id).set(n.toMap());
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
