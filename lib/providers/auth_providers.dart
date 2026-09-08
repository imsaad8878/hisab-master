import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../models/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateChangesProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Null while the app is signed out.
final currentUidProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  return user?.uid;
});

/// Where transactions belong. Firebase UID keeps data tied to the account
/// so reinstall + same login restores everything.
final dataUidProvider = Provider<String>((ref) {
  return ref.watch(currentUidProvider) ?? 'signed_out';
});
