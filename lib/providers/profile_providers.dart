import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/user_profile_repository.dart';
import '../models/app_user.dart';
import 'auth_providers.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final repo = UserProfileRepository();
  repo.initLocal();
  return repo;
});

/// Raw editable profile doc: {name: String?, photo: String?(base64)}
final profileDocProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final uid = ref.watch(dataUidProvider);
  if (uid == 'signed_out') return Stream.value(const {});
  return ref.watch(userProfileRepositoryProvider).watch(uid);
});

/// Auth user merged with custom name/photo — use this wherever the user's
/// identity is displayed.
final displayUserProvider = Provider<AppUser?>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return null;
  final doc = ref.watch(profileDocProvider).valueOrNull ?? const {};
  return AppUser(
    uid: user.uid,
    displayName: (doc['name'] as String?)?.trim().isNotEmpty == true
        ? doc['name'] as String
        : user.displayName,
    email: user.email,
    photoURL: user.photoURL,
    photoBase64: doc['photo'] as String?,
    isAnonymous: user.isAnonymous,
    emailVerified: user.emailVerified,
  );
});
