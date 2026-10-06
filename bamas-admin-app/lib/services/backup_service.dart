import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import 'api_client.dart';

/// Full data export/restore (menu, categories, offers, shop settings,
/// orders, users, reviews, enquiries -- everything).
///
/// Two formats:
///  * Excel (.xlsx)  -- the one to use. Readable, and it is the ONLY
///    format the restore endpoint accepts, because the export writes a
///    hidden `_meta` sheet recording each column's type and each
///    collection's id kind. That is what lets a restore put every
///    document back under its ORIGINAL _id -- so a customer's old orders
///    stay attached to that customer instead of being orphaned.
///  * JSON -- the older export, kept for anyone who already has one.
///
/// The weekly AUTOMATED backup does not go through this app at all; it
/// calls the backend's /backup/excel/scheduled endpoint on its own.
class BackupService {
  static const _lastBackupKey = 'bamas_last_backup_at';

  /// How often the screen nags for a fresh download.
  static const backupEveryDays = 7;

  Future<List<int>> downloadExcelBackup() async {
    if (kDemoMode) throw UnimplementedError('Backup is not available in demo mode.');
    final bytes = await apiClient.getBytes('/backup/excel');
    await _markBackedUp();
    return bytes;
  }

  Future<List<int>> downloadFullBackup() async {
    if (kDemoMode) throw UnimplementedError('Backup is not available in demo mode.');
    final bytes = await apiClient.getBytes('/backup/full');
    await _markBackedUp();
    return bytes;
  }

  /// Sends the spreadsheet back to the server, which REPLACES the
  /// collections it finds in the file. The backend parses the whole file
  /// before it writes anything, so a damaged or wrong file is rejected
  /// with a 400 and the live data is left untouched.
  Future<Map<String, dynamic>> restoreFromExcel(
    List<int> bytes, {
    String filename = 'backup.xlsx',
  }) async {
    if (kDemoMode) throw UnimplementedError('Restore is not available in demo mode.');
    final res = await apiClient.uploadBytes(
      '/backup/restore',
      bytes,
      field: 'file',
      filename: filename,
      query: const {'confirm': 'REPLACE-ALL-DATA'},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> _markBackedUp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// True when it has been a week (or more) since the last download from
  /// this phone -- or when there has never been one.
  Future<bool> isBackupDue() async {
    final last = await lastBackupAt();
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= backupEveryDays;
  }
}

final backupService = BackupService();
