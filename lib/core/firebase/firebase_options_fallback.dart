import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import 'firebase_bootstrap.dart';

bool get isFallbackOptions => !FirebaseService.ready;

FirebaseOptions? get appOptions {
  if (!FirebaseService.ready) return null;
  return DefaultFirebaseOptions.currentPlatform;
}
