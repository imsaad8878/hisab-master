import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/category_tag.dart';

/// User-defined categories (on top of the built-in defaults),
/// each tagged as income or expense.
///
/// Local writes wait for [initLocal] so an early add can never wipe the
/// stored list; the first Firebase login also migrates local categories.
class CategoryRepository {
  CategoryRepository();

  static const String _prefsKey = 'hisab_custom_categories_v2';
  static const String _migratedKey = 'hisab_categories_migrated_v1';

  final StreamController<List<CategoryTag>> _localController =
      StreamController.broadcast();
  List<CategoryTag> _localCache = [];
  Future<void>? _initFuture;
  bool _migrated = false;

  CollectionReference<Map<String, dynamic>> _col(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('categories');

  /// Completes once local storage is safe to read and write.
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
          final items = <CategoryTag>[];
          for (final m in decoded) {
            if (m is! Map) continue;
            final c = CategoryTag.fromMap(m.cast<String, dynamic>());
            if (c.name.trim().isEmpty) continue;
            items.add(c);
          }
          _localCache = items;
          _localController.add(_localCache);
        } catch (_) {
          // Corrupt payload: leave the stored string untouched (never
          // overwrite a user's data with an empty list).
        }
      }
    } catch (_) {}
  }

  Stream<List<CategoryTag>> watchCategories(String uid) async* {
    if (!FirebaseService.useLocal) {
      await initLocal();
      yield _localCache;
      yield* _localController.stream;
      return;
    }
    unawaited(ensureMigratedToCloud(uid));
    yield* _col(uid).snapshots().map((snap) {
      final tags = snap.docs
          .map((d) => CategoryTag(
                name: (d.data()['name'] as String?) ?? d.id,
                type: d.data()['type'] as String? ?? 'expense',
              ))
          .where((c) => c.name.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return tags;
    });
  }

  Future<void> _emitLocal(List<CategoryTag> next) async {
    _localCache = next;
    _localController.add(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode([for (final c in next) c.toMap()]));
    } catch (_) {}
  }

  Future<String?> addCategory(String uid, String name, String type) async {
    final clean = name.trim();
    if (clean.isEmpty) return 'Category naam khali hobe na.';
    if (clean.length > 20) return 'Category naam beshi boro (max 20 letters).';
    final dupDefault = kCategoriesByTypeName[type]!
        .any((c) => c.toLowerCase() == clean.toLowerCase());
    if (dupDefault) return 'Ei default category te ache already.';
    if (!FirebaseService.useLocal) {
      await initLocal();
      if (_localCache.any((c) =>
          c.type == type && c.name.toLowerCase() == clean.toLowerCase())) {
        return 'Ei category agei ache.';
      }
      await _emitLocal([..._localCache, CategoryTag(name: clean, type: type)]);
      return null;
    }
    await ensureMigratedToCloud(uid);
    final existing = await _col(uid).get();
    final dup = existing.docs.any((d) =>
        (d.data()['type'] ?? 'expense') == type &&
        (((d.data()['name'] as String?) ?? d.id).toLowerCase() ==
            clean.toLowerCase()));
    if (dup) return 'Ei category agei ache.';
    await _col(uid).add({
      'name': clean,
      'type': type,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return null;
  }

  Future<void> deleteCategory(String uid, CategoryTag tag) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      await _emitLocal(_localCache
          .where((c) =>
              !(c.type == tag.type &&
                  c.name.toLowerCase() == tag.name.toLowerCase()))
          .toList());
      return;
    }
    final snap = await _col(uid).get();
    for (final d in snap.docs) {
      if ((d.data()['type'] ?? 'expense') == tag.type &&
          (((d.data()['name'] as String?) ?? d.id).toLowerCase() ==
              tag.name.toLowerCase())) {
        await d.reference.delete();
      }
    }
  }

  /// One-time copy of on-device custom categories into Firestore.
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
              final c = CategoryTag.fromMap(m);
              if (c.name.trim().isEmpty) continue;
              batch.set(_col(uid).doc(), {
                'name': c.name,
                'type': c.type,
                'createdAt': DateTime.now().toIso8601String(),
              });
            }
            await batch.commit();
          }
        }
      }
      await prefs.setBool(_migratedKey, true);
    } catch (_) {
      _migrated = false;
    }
  }
}
