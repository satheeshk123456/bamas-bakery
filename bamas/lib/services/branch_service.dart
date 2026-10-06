import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/branch.dart';
import 'api_service.dart';

/// Which branch this phone is ordering from.
///
/// The choice is saved on the device, so a returning customer goes straight
/// to the menu instead of being asked again every launch. It is deliberately
/// NOT tied to the customer's account: the same person may order from the
/// branch near work on weekdays and the one near home at weekends, and on
/// the backend an order carries the branch, not the customer.
class BranchService {
  BranchService._();
  static final BranchService instance = BranchService._();

  static const _prefsKey = 'bamas_selected_branch';

  /// Screens listen to this to rebuild when the branch changes. Holds null
  /// until a branch has been chosen.
  final ValueNotifier<Branch?> selected = ValueNotifier<Branch?>(null);

  Branch? get current => selected.value;
  String? get currentId => selected.value?.id;
  bool get hasSelection => (selected.value?.id ?? '').isNotEmpty;

  /// Every branch, freshest first read. Cached in memory for the life of
  /// the app so the picker and the settings overlay share one fetch.
  List<Branch> _all = const [];
  List<Branch> get all => _all;

  /// Restores the saved choice before the first frame (called from main()).
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final stored = Branch.fromStoredMap(Map<String, dynamic>.from(jsonDecode(raw)));
      if (stored.id.isEmpty) return;
      selected.value = stored;
    } catch (_) {
      // A corrupt or unreadable preference just means "not chosen yet".
    }
  }

  Future<List<Branch>> fetchBranches() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/branches'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Could not load branches (${res.statusCode})');
    }
    final list = (jsonDecode(res.body) as List?) ?? const [];
    _all = list
        .map((m) => Branch.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Refresh the live details behind the saved choice, and drop the
    // selection entirely if that branch has since been removed -- otherwise
    // the customer would keep ordering into a branch that no longer exists.
    final chosen = selected.value;
    if (chosen != null) {
      final match = _all.where((b) => b.id == chosen.id).toList();
      if (match.isEmpty) {
        await clear();
      } else {
        selected.value = match.first;
      }
    }
    return _all;
  }

  Future<void> select(Branch branch) async {
    final changed = branch.id != selected.value?.id;
    selected.value = branch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(branch.toStoredMap()));
    if (changed) {
      // The menu, the shop settings and the featured list are all
      // branch-specific. Without this the customer switches branch and
      // keeps seeing the previous branch's food until the poll interval
      // happens to expire.
      ApiService.clearCache();
    }
  }

  Future<void> clear() async {
    selected.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    ApiService.clearCache();
  }
}
