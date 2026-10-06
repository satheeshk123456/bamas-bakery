import '../app_config.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'session.dart';

class AuthService {
  Future<void> login(String username, String password) async {
    if (kDemoMode) {
      await apiClient.saveToken('demo-token');
      await session.save(role: Session.roleSuperAdmin, name: 'Demo');
      return;
    }
    final result = await apiClient.post(
      '/auth/login',
      body: {'username': username, 'password': password},
      auth: false,
    );
    await apiClient.saveToken(result['access_token'] as String);

    // The backend decides the role; this is only stored so the app knows
    // which screens to draw. An older backend (before multi-branch) returns
    // no role at all, and Session treats that as full access -- so updating
    // the app before the server never locks the owner out.
    final map = (result as Map).cast<String, dynamic>();
    await session.save(
      role: (map['role'] ?? '') as String,
      branchId: map['branchId'] as String?,
      name: (map['name'] ?? '') as String,
    );

    // Point this phone's push notifications at the right branch.
    await NotificationService.applySubscriptions();
  }

  Future<void> logout() async {
    // Unsubscribe FIRST: a phone that keeps its old topic would carry on
    // buzzing for a branch whose manager has handed the phone back.
    await NotificationService.clearSubscriptions();
    await session.clear();
    await apiClient.clearToken();
  }

  Future<bool> get isLoggedIn => apiClient.isLoggedIn;
}

final authService = AuthService();
