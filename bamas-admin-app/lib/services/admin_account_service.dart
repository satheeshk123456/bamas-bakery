import '../models/branch.dart';
import 'api_client.dart';

/// Staff logins. Every route here is super-admin-only on the backend, so
/// the screen that uses it is hidden from everyone else -- and would get a
/// 403 anyway if it weren't.
class AdminAccountService {
  Future<List<AdminAccount>> list() async {
    final result = await apiClient.get('/admins');
    return ((result as List?) ?? const [])
        .map((e) => AdminAccount.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<AdminAccount> create({
    required String username,
    required String password,
    required String name,
    required String role,
    String? branchId,
  }) async {
    final result = await apiClient.post('/admins', body: {
      'username': username,
      'password': password,
      'name': name,
      'role': role,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
    });
    return AdminAccount.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<AdminAccount> update(String id, Map<String, dynamic> changes) async {
    final result = await apiClient.patch('/admins/$id', body: changes);
    return AdminAccount.fromJson((result as Map).cast<String, dynamic>());
  }
}

final adminAccountService = AdminAccountService();
