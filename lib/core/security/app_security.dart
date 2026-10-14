import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local security settings (PIN lock). Never synced to the cloud —
/// a lock that travels to other devices is no lock at all.
class AppSecurity {
  AppSecurity._();

  static const String _pinKey = 'hisab_app_lock_pin';
  static const String _bioKey = 'hisab_app_lock_bio';

  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('hisab:$pin')).toString();

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, hashPin(pin));
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) == hashPin(pin);
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_bioKey, false);
  }

  static Future<bool> biometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bioKey) ?? false;
  }

  static Future<void> setBiometricEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bioKey, on);
  }
}
