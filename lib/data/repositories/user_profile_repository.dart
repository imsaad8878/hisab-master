import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';

/// Editable profile data (name + custom picture), layered on top of the
/// auth account. Stored in Firestore at users/{uid}/profile/data, or in
/// SharedPreferences in demo mode.
class UserProfileRepository {
  UserProfileRepository();

  static const String _prefsKey = 'hisab_user_profile_v1';

  final StreamController<Map<String, dynamic>> _localController =
      StreamController.broadcast();
  Map<String, dynamic> _localCache = {};

  DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('profile')
      .doc('data');

  Future<void> initLocal() async {
    if (FirebaseService.ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _localCache = (jsonDecode(raw) as Map).cast<String, dynamic>();
      }
    } catch (_) {}
  }

  Stream<Map<String, dynamic>> watch(String uid) async* {
    if (!FirebaseService.ready) {
      yield _localCache;
      yield* _localController.stream;
      return;
    }
    yield* _doc(uid).snapshots().map((s) => s.data() ?? const {});
  }

  Future<void> _write(String uid, Map<String, dynamic> patch) async {
    if (!FirebaseService.ready) {
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

  static String encodeBase64(List<int> bytes) => base64Encode(bytes);
}
