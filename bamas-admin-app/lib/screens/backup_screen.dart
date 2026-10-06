import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';

/// Weekly data backup, and the restore that goes with it.
///
/// Download writes ONE spreadsheet holding everything -- menu,
/// categories, offers, shop settings, orders, customers, reviews and
/// enquiries -- which can be saved to Google Drive, emailed, or kept on
/// this phone. Restore sends that same spreadsheet back if data is ever
/// lost. Every row keeps its original id, so restored orders are still
/// attached to the customers who placed them.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _working = false;
  String? _status;
  String? _error;
  DateTime? _lastBackupAt;
  bool _due = true;

  @override
  void initState() {
    super.initState();
    _refreshLastBackup();
  }

  Future<void> _refreshLastBackup() async {
    final last = await backupService.lastBackupAt();
    final due = await backupService.isBackupDue();
    if (mounted) setState(() { _lastBackupAt = last; _due = due; });
  }

  Future<void> _shareBytes(List<int> bytes, String fileName, String subject) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: subject));
  }

  Future<void> _downloadExcel() async {
    setState(() { _working = true; _error = null; _status = null; });
    try {
      final bytes = await backupService.downloadExcelBackup();
      final name = 'bamas-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      await _shareBytes(bytes, name, "Bama's Burger Box backup ($name)");
      if (mounted) setState(() => _status = 'Backup saved. Keep it somewhere safe.');
      await _refreshLastBackup();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create backup: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _downloadJson() async {
    setState(() { _working = true; _error = null; _status = null; });
    try {
      final bytes = await backupService.downloadFullBackup();
      final name = 'bamas-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      await _shareBytes(bytes, name, "Bama's Burger Box backup ($name)");
      if (mounted) setState(() => _status = 'JSON copy saved.');
      await _refreshLastBackup();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create backup: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    setState(() { _error = null; _status = null; });

    PlatformFile? picked;
    try {
      // No extension filter on purpose: Android's picker filters by MIME
      // type, and a .xlsx that arrived via Drive/Gmail often reports a
      // generic one -- with a custom filter the owner simply cannot see
      // their own backup. We check the extension ourselves below instead.
      picked = await FilePicker.pickFile(dialogTitle: 'Pick the backup .xlsx file');
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the file picker: $e');
      return;
    }
    if (picked == null) return;

    final name = picked.name;
    if (!name.toLowerCase().endsWith('.xlsx')) {
      setState(() => _error = 'Pick the .xlsx backup file, not "$name".');
      return;
    }

    if (!mounted) return;
    final ok = await _confirmRestore(name);
    if (ok != true) return;

    setState(() { _working = true; });
    try {
      final bytes = await picked.readAsBytes();
      final report = await backupService.restoreFromExcel(bytes, filename: name);
      if (!mounted) return;
      setState(() { _working = false; _status = 'Restore finished.'; });
      await _showReport(report);
    } catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = 'Restore failed, and nothing was changed: $e';
        });
      }
    }
  }

  /// Two deliberate steps -- a checkbox AND a red button -- because this
  /// wipes what is currently in the shop's database and a mis-tap on a
  /// phone must not be enough to do it.
  Future<bool?> _confirmRestore(String fileName) {
    var understood = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Replace all data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $fileName', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text(
                'Everything currently in the shop -- menu, orders, customers, '
                'settings -- is replaced by what is in this file. Orders placed '
                'after the file was downloaded will be gone.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Tip: download a fresh backup first, so you can undo this.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: understood,
                onChanged: (v) => setLocal(() => understood = v ?? false),
                title: const Text('I understand this replaces everything',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: understood ? () => Navigator.pop(context, true) : null,
              child: const Text('Replace all data'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReport(Map<String, dynamic> report) async {
    final counts = Map<String, dynamic>.from(report['collections'] as Map? ?? {});
    final warnings = List<dynamic>.from(report['warnings'] as List? ?? []);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore complete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${report['totalDocuments'] ?? 0} records restored.'),
              const SizedBox(height: 10),
              ...counts.entries.map((e) => Text('${_label(e.key)}: ${e.value}',
                  style: const TextStyle(fontSize: 13))),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Skipped rows:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ...warnings.map((w) => Text('- $w',
                    style: const TextStyle(fontSize: 12, color: Colors.orange))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  static String _label(String key) {
    switch (key) {
      case 'menuItems': return 'Menu items';
      case 'categories': return 'Categories';
      case 'offers': return 'Offers';
      case 'shopSettings': return 'Shop settings';
      case 'orders': return 'Orders';
      case 'users': return 'Customers';
      case 'reviews': return 'Reviews';
      case 'enquiries': return 'Enquiries';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Backup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_due)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_repeat, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastBackupAt == null
                            ? 'No backup taken from this phone yet. Take one now.'
                            : "It's been a week since the last backup. Take a new one.",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            if (_due) const SizedBox(height: 18),

            const Text('Weekly backup',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Saves everything -- menu, categories, offers, shop settings, '
              'orders, customers, reviews and enquiries -- into one Excel '
              'file you can keep in Google Drive or email to yourself.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _working ? null : _downloadExcel,
              icon: _working
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.file_download_outlined),
              label: Text(_working ? 'Working...' : 'Download backup (Excel)'),
            ),
            if (_lastBackupAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Last backup ${DateFormat('MMM d, h:mm a').format(_lastBackupAt!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: _working ? null : _downloadJson,
              child: const Text('Download as JSON instead', style: TextStyle(fontSize: 12)),
            ),

            const Divider(height: 40),

            const Text('Restore from a backup',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Only if data is lost. Pick an Excel backup file and everything '
              'goes back exactly as it was -- each order stays attached to the '
              'customer who placed it, so customers still see their old orders.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'The file is checked first. If it is the wrong file or damaged, '
              'nothing is changed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _working ? null : _restore,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Restore from Excel file'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),

            if (_status != null) ...[
              const SizedBox(height: 18),
              Text(_status!, style: const TextStyle(color: Colors.green)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
