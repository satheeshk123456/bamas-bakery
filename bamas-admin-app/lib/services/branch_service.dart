import '../app_config.dart';
import '../models/branch.dart';
import 'api_client.dart';

/// Branches, for the admin app.
///
/// The list is cached in memory because several screens need it at once
/// (the orders header, the "which branch sells this?" dropdown when adding
/// an item, the staff-login form) and it changes about once a year.
class BranchService {
  List<Branch> _cache = const [];
  List<Branch> get cached => _cache;

  Future<List<Branch>> list({bool force = false}) async {
    if (kDemoMode) {
      _cache = const [Branch(id: 'demo-branch', name: 'Demo Branch', isOpen: true)];
      return _cache;
    }
    if (_cache.isNotEmpty && !force) return _cache;
    // includeInactive: the owner still has to be able to see, and re-open,
    // a branch they switched off.
    final result = await apiClient.get('/branches', query: {'includeInactive': 'true'});
    _cache = ((result as List?) ?? const [])
        .map((e) => Branch.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return _cache;
  }

  Branch? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final b in _cache) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Super admin only -- the backend returns 403 for anyone else.
  Future<Branch> create({
    required String name,
    String address = '',
    String contactPhone = '',
    String upiId = '',
  }) async {
    final result = await apiClient.post('/branches', body: {
      'name': name,
      'address': address,
      'contactPhone': contactPhone,
      'upiId': upiId,
      'isOpen': true,
    });
    _cache = const [];
    return Branch.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<Branch> update(String id, Map<String, dynamic> changes) async {
    final result = await apiClient.patch('/branches/$id', body: changes);
    _cache = const [];
    return Branch.fromJson((result as Map).cast<String, dynamic>());
  }
}

final branchService = BranchService();
