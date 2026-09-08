import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError {
      // firebase_options.dart not generated yet — fall back to
      // android/app/google-services.json (Android only).
      await Firebase.initializeApp();
    }
    FirebaseService.ready = true;
  } catch (e) {
    FirebaseService.ready = false;
    FirebaseService.initError = e.toString();
  }
  runApp(const ProviderScope(child: HisabMasterApp()));
}
