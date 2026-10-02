import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which leave decisions the employee has already seen, so the
/// History tab can show a dot when HR has acted since they last looked.
/// Purely local — the backend has no notion of "read".
class UnseenDecisions {
  UnseenDecisions._();

  static const _key = 'history_last_seen_at';

  static Future<DateTime?> lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
  }

  /// Counts entries reviewed after [since]. A null [since] means the
  /// employee has never opened History, so everything settled counts.
  static int countSince(List<dynamic> apps, DateTime? since) {
    return apps.where((a) {
      final raw = (a is Map ? a['reviewed_at'] : null)?.toString();
      final reviewed = DateTime.tryParse(raw ?? '');
      if (reviewed == null) return false;
      return since == null || reviewed.isAfter(since);
    }).length;
  }
}
