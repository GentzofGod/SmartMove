import 'package:shared_preferences/shared_preferences.dart';

/// Service managing the start screen guide and onboarding visibility status.
class GuideService {
  static const String _storageKey = 'smartmove_has_seen_start_guide_v1';

  /// Check whether the user has already viewed and completed or skipped the start guide.
  static Future<bool> hasSeenGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_storageKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mark the start screen guide as seen so it will not appear on subsequent launches.
  static Future<void> markGuideSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, true);
    } catch (_) {}
  }

  /// Reset the start screen guide status (useful for settings / replay guide).
  static Future<void> resetGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
