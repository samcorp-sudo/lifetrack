import 'package:shared_preferences/shared_preferences.dart';

/// A single local device profile (no login/accounts — see product decision
/// to defer auth). Stored in SharedPreferences, not SQLite, since it's
/// app-level settings rather than trackable data.
class UserProfile {
  final String displayName;
  final String? avatarEmoji;

  const UserProfile({required this.displayName, this.avatarEmoji});

  static const _keyName = 'profile_display_name';
  static const _keyAvatar = 'profile_avatar_emoji';
  static const _defaultName = 'You';

  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      displayName: prefs.getString(_keyName) ?? _defaultName,
      avatarEmoji: prefs.getString(_keyAvatar),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, displayName);
    if (avatarEmoji != null) {
      await prefs.setString(_keyAvatar, avatarEmoji!);
    }
  }
}