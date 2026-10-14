import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';

/// Editable profile data (name + custom picture), layered on top of the
/// auth account. Stored in Firestore at users/{uid}/profile/data, or in
/// SharedPreferences in demo mode.
///
/// Local writes wait for [initLocal] so an early save can never wipe the
/// stored profile; the first Firebase login migrates the local profile.
class UserProfileRepository {
  UserProfileRepository();

  static const String _prefsKey = 'hisab_user_profile_v1';
  static const String _migratedKey = 'hisab_profile_migrated_v1';

  final StreamController<Map<String, dynamic>> _localController =
      StreamController.broadcast();
  Map<String, dynamic> _localCache = {};
  Future<void>? _initFuture;
  bool _migrated = false;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('profile')
      .doc('data');

  /// Completes once local storage is safe to read and write.
  Future<void> initLocal() => _initFuture ??= _initLocal();

  Future<void> _initLocal() async {
    if (FirebaseService.useLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        try {
          _localCache = (jsonDecode(raw) as Map).cast<String, dynamic>();
        } catch (_) {
          // Corrupt payload: leave the stored string untouched.
        }
      }
    } catch (_) {}
  }

  Stream<Map<String, dynamic>> watch(String uid) async* {
    if (!FirebaseService.useLocal) {
      await initLocal();
      yield _localCache;
      yield* _localController.stream;
      return;
    }
    unawaited(ensureMigratedToCloud(uid));
    yield* _doc(uid).snapshots().map((s) => s.data() ?? const {});
  }

  Future<void> _write(String uid, Map<String, dynamic> patch) async {
    if (!FirebaseService.useLocal) {
      await initLocal();
      _localCache = {..._localCache, ...patch};
      _localController.add(_localCache);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(_localCache));
      } catch (_) {}
      return;
    }
    await _doc(uid).set(patch, SetOptions(merge: true));
  }

  Future<void> setName(String uid, String name) =>
      _write(uid, {'name': name.trim()});

  /// Pass null to remove the custom picture.
  Future<void> setPhoto(String uid, String? base64) =>
      _write(uid, {'photo': base64});

  /// One-time copy of the on-device profile (name/photo) into Firestore.
  Future<void> ensureMigratedToCloud(String uid) async {
    if (_migrated) return;
    _migrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migratedKey) ?? false) return;
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final remote = await _doc(uid).get();
        if (!remote.exists &&
            ((map['name'] as String?)?.isNotEmpty ?? false)) {
          await _doc(uid).set({
            'name': map['name'],
            if (map['photo'] != null) 'photo': map['photo'],
          });
        }
      }
      await prefs.setBool(_migratedKey, true);
    } catch (_) {
      _migrated = false;
    }
  }

  static String encodeBase64(List<int> bytes) => base64Encode(bytes);
}
