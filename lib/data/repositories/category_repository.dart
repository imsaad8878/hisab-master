import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/category_tag.dart';

/// User-defined categories (on top of the built-in defaults),
/// each tagged as income or expense.
class CategoryRepository {
  CategoryRepository();

  static const String _prefsKey = 'hisab_custom_categories_v2';

  final StreamController<List<CategoryTag>> _localController =
      StreamController.broadcast();
  List<CategoryTag> _localCache = [];

  CollectionReference<Map<String, dynamic>> _col(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('categories');

  Future<void> initLocal() async {
    if (FirebaseService.ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _localCache = [for (final m in list) CategoryTag.fromMap(m)];
        _localController.add(_localCache);
      }
    } catch (_) {}
  }

  Stream<List<CategoryTag>> watchCategories(String uid) async* {
    if (!FirebaseService.ready) {
      yield _localCache;
      yield* _localController.stream;
      return;
    }
    yield* _col(uid).snapshots().map((snap) {
      final tags = snap.docs
          .map((d) => CategoryTag(
                name: (d.data()['name'] as String?) ?? d.id,
                type: d.data()['type'] as String? ?? 'expense',
              ))
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
    if (!FirebaseService.ready) {
      if (_localCache.any((c) =>
          c.type == type && c.name.toLowerCase() == clean.toLowerCase())) {
        return 'Ei category agei ache.';
      }
      await _emitLocal([..._localCache, CategoryTag(name: clean, type: type)]);
      return null;
    }
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
    if (!FirebaseService.ready) {
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
}
