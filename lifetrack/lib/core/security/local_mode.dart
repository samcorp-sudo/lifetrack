import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Signed-out mode": after the user taps Sign out, LifeTrack keeps working
/// with the data stored on this phone and stays on the Dashboard instead of
/// showing the login screen. Nothing is deleted when signing out.
///
/// - Set to true by Profile -> Sign out (before the real sign out runs).
/// - Set back to false when the user taps Sign in, or signs in again.
class LocalMode {
  static const _key = 'auth.stay_local_after_sign_out';

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  /// Call once in main() before runApp.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_key) ?? false;
    } catch (_) {
      enabled.value = false;
    }
  }

  static Future<void> set(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(_key, true);
      } else {
        await prefs.remove(_key);
      }
    } catch (_) {
      // Non-critical: the in-memory value still applies for this session.
    }
  }
}
