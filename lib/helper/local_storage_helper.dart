import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageHelper {
  static const String _key = 'tracking_history'; // Changed key name for clarity

  // Defines the structure for tracking data in local storage
  // 'data' will contain the location/battery info
  // 'status' will be 'pending', 'sent', or 'error'
  // 'attempted_at' is the time the send was tried
  // 'id' is a unique identifier (optional, but helpful)

  /// Save a new tracking data attempt to local storage.
  static Future<void> saveTrackingAttempt(
    Map<String, dynamic> data,
    String status,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> existing = prefs.getStringList(_key) ?? [];

    // Create a unique ID and current timestamp for this record
    final timestamp = DateTime.now().toIso8601String();
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();

    final record = {
      'id': uniqueId,
      'data': data,
      'status': status,
      'attempted_at': timestamp,
    };

    existing.add(jsonEncode(record));
    await prefs.setStringList(_key, existing);
  }

  /// Get all tracking history.
  static Future<List<Map<String, dynamic>>> getAllTrackingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stored = prefs.getStringList(_key) ?? [];
    return stored.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// Get only the data that needs syncing (e.g., status: 'pending' or 'error').
  static Future<List<Map<String, dynamic>>> getUnsentLocations() async {
    final history = await getAllTrackingHistory();
    return history.where((record) => record['status'] != 'sent').toList();
  }

  /// Update the status of a specific tracking record by its ID.
  static Future<void> updateRecordStatus(String id, String newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> existing = prefs.getStringList(_key) ?? [];

    List<Map<String, dynamic>> records = existing
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();

    // Find the record and update its status
    final index = records.indexWhere((record) => record['id'] == id);
    if (index != -1) {
      records[index]['status'] = newStatus;

      // Re-encode and save the list
      List<String> updatedStrings = records.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList(_key, updatedStrings);
    }
  }

  /// Delete records older than a specified duration (e.g., 3 hours).
  static Future<void> cleanupOldRecords({int olderThanHours = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> existing = prefs.getStringList(_key) ?? [];

    List<Map<String, dynamic>> records = existing
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();

    final cutoffTime = DateTime.now().subtract(Duration(hours: olderThanHours));

    // Filter out records older than the cutoff time
    final freshRecords = records.where((record) {
      try {
        final attemptedAt = DateTime.parse(record['attempted_at'] as String);
        return attemptedAt.isAfter(cutoffTime);
      } catch (e) {
        // Keep records with invalid timestamps as a failsafe
        return true;
      }
    }).toList();

    // Save only the fresh records back
    List<String> freshStrings = freshRecords.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_key, freshStrings);
  }

  /// Clear all saved history (optional, for testing/reset).
  static Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

Future<void> saveTrackingState(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isTracking', value);
}

Future<bool> getTrackingState() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isTracking') ?? false;
}