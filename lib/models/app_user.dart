class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
    this.photoBase64,
    this.isAnonymous = false,
    this.emailVerified = false,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;

  /// Custom-uploaded profile picture stored as base64.
  final String? photoBase64;
  final bool isAnonymous;
  final bool emailVerified;
}
