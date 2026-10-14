import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../models/app_user.dart';

/// Paste the "Web client ID" (OAuth) from Firebase console:
/// Authentication > Google (enabled) > "Copy" under Web client.
/// Needed only for Google Sign-In to return an idToken on Android.
const String kGoogleServerClientId =
    '997907494291-se97be7fgbs221o5ggbd6buj4pjci8i8.apps.googleusercontent.com';

AppUser _toAppUser(User u) => AppUser(
      uid: u.uid,
      displayName: u.displayName,
      email: u.email,
      photoURL: u.photoURL,
      isAnonymous: u.isAnonymous,
      emailVerified: u.emailVerified,
    );

class AuthRepository {
  AuthRepository();

  static final AppUser demoUser = AppUser(
    uid: FirebaseService.demoUid,
    displayName: 'Demo user (offline mode)',
    email: 'Firebase not configured yet',
    isAnonymous: true,
  );

  final StreamController<AppUser?> _demoController =
      StreamController<AppUser?>.broadcast();
  bool _demoSignedIn = false;

  Stream<AppUser?> authStateChanges() {
    if (!FirebaseService.ready) {
      return _demoController.stream;
    }
    // userChanges() also fires on profile reloads, so an email that was
    // verified in the browser updates the app after refreshUser().
    return FirebaseAuth.instance.userChanges().map(
          (u) => u == null ? null : _toAppUser(u),
        );
  }

  /// Re-reads the signed-in account from Firebase. Needed because
  /// `emailVerified` is cached until reload() is called — without this a
  /// verified Gmail keeps showing "Email not verified" in settings.
  Future<void> refreshUser() async {
    if (!FirebaseService.ready) return;
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}
  }

  AppUser? get currentUser {
    if (!FirebaseService.ready) return _demoSignedIn ? demoUser : null;
    final u = FirebaseAuth.instance.currentUser;
    return u == null ? null : _toAppUser(u);
  }

  void continueAsDemo() {
    _demoSignedIn = true;
    _demoController.add(demoUser);
  }

  Future<void> signOut() async {
    if (!FirebaseService.ready) {
      _demoSignedIn = false;
      _demoController.add(null);
      return;
    }
    try {
      await GoogleSignIn(
        serverClientId: kGoogleServerClientId.startsWith('REPLACE_WITH')
            ? null
            : kGoogleServerClientId,
      ).signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  Future<String> signInWithGoogle() async {
    if (!FirebaseService.ready) return _firebaseNotConfigured;
    try {
      final google = GoogleSignIn(
        scopes: const ['email'],
        serverClientId: kGoogleServerClientId.startsWith('REPLACE_WITH')
            ? null
            : kGoogleServerClientId,
      );
      final account = await google.signIn();
      if (account == null) return ''; // user cancelled
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        return 'Google did not return an idToken. Open Firebase console > '
            'Authentication > Google and copy the Web client ID into '
            'kGoogleServerClientId (auth_repository.dart).';
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      return '';
    } on FirebaseAuthException catch (e) {
      return _message(e);
    } catch (e) {
      return 'Google sign-in failed: $e';
    }
  }

  Future<String> signInWithEmail(String email, String password) async {
    if (!FirebaseService.ready) return _firebaseNotConfigured;
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      return '';
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<String> registerWithEmail(
      String name, String email, String password) async {
    if (!FirebaseService.ready) return _firebaseNotConfigured;
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.sendEmailVerification();
      return '';
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<void> sendEmailVerification() async {
    if (!FirebaseService.ready) return;
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
  }

  /// Sends a password-reset link to [email].
  /// Returns '' on success, otherwise an error message.
  Future<String> sendPasswordResetEmail(String email) async {
    if (!FirebaseService.ready) return _firebaseNotConfigured;
    final clean = email.trim();
    if (clean.isEmpty || !clean.contains('@')) {
      return 'Email ta thik nai.';
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: clean);
      return '';
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  /// Returns null on success, otherwise an error message.
  Future<String?> updatePassword(String newPassword) async {
    if (!FirebaseService.ready) {
      return 'Password change only works in Firebase mode (not demo).';
    }
    if (newPassword.length < 6) return 'Password kom-pakhe 6 ta hote hobe.';
    try {
      await FirebaseAuth.instance.currentUser!
          .updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Security jonno age ekbar logout hoye abar login hobe, '
            'tarpor password change korun.';
      }
      return _message(e);
    }
  }

  static const String _firebaseNotConfigured =
      'Firebase is not configured on this build yet. '
      'Run "flutterfire configure" and rebuild, '
      'or continue in demo mode below.';

  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email ta thik nai.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ba password vul.';
      case 'email-already-in-use':
        return 'Ei email diye agei account ache.';
      case 'weak-password':
        return 'Password aro strong korun (6+ characters).';
      case 'too-many-requests':
        return 'Onek try korechen. Ektu pore abara chesta korun.';
      case 'network-request-failed':
        return 'Internet connection nai.';
      default:
        return 'Auth error: ${e.message ?? e.code}';
    }
  }
}
