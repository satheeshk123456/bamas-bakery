import '../app_config.dart';
import 'api_client.dart';

class AuthService {
  Future<void> login(String username, String password) async {
    if (kDemoMode) {
      await apiClient.saveToken('demo-token');
      return;
    }
    final result = await apiClient.post(
      '/auth/login',
      body: {'username': username, 'password': password},
      auth: false,
    );
    await apiClient.saveToken(result['access_token'] as String);
  }

  Future<void> logout() => apiClient.clearToken();

  Future<bool> get isLoggedIn => apiClient.isLoggedIn;
}

final authService = AuthService();
