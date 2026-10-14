class FirebaseService {
  FirebaseService._();

  static bool ready = false;
  static String? initError;

  /// True after the user picks "Continue offline" — all data stays on the
  /// device even though Firebase itself is configured. Cleared on sign-out.
  static bool demoMode = false;

  /// Local (on-device) storage is used when Firebase is missing OR the
  /// user explicitly chose offline mode.
  static bool get useLocal => !ready || demoMode;

  static const String demoUid = 'demo_local_user';
}
