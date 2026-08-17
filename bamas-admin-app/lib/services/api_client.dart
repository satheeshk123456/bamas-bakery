import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around the bamas-admin-backend FastAPI server. Stores the
/// JWT from /auth/login in SharedPreferences and attaches it to every
/// subsequent request.
class ApiClient {
  static const _tokenKey = 'bamas_admin_token';

  Future<String?> get _token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> get isLoggedIn async => (await _token) != null;

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _token;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$kApiBaseUrl$path').replace(queryParameters: query);

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) message = body['detail'].toString();
    } catch (_) {}
    throw ApiException(res.statusCode, message);
  }

  Future<dynamic> get(String path, {Map<String, String>? query, bool auth = true}) async {
    final res = await http.get(_uri(path, query), headers: await _headers(auth: auth));
    return _decode(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final res = await http.post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final res = await http.patch(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  /// Multipart upload for a menu-item photo picked from the gallery.
  /// Expects the backend to return JSON like `{"imageUrl": "https://..."}`.
  Future<dynamic> uploadFile(String path, File file, {String field = 'file'}) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final token = await _token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(field, file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }
}

final apiClient = ApiClient();
