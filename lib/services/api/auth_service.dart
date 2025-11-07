import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'providers.dart';

class AuthService {
  final ApiClient api;
  final FlutterSecureStorage storage;
  final Ref tokenProvider;

  AuthService({
    required this.api,
    required this.storage,
    required this.tokenProvider,
  });

  Future<void> saveToken(String token) async {
    await storage.write(key: 'token', value: token);
    tokenProvider.read(authTokenProvider.notifier).state = token;
  }

  Future<void> clearToken() async {
    await storage.delete(key: 'token');
    tokenProvider.read(authTokenProvider.notifier).state = null;
  }

  Future<String?> readSavedToken() => storage.read(key: 'token');

Future<Map<String, dynamic>?> login({
  required String email,
  required String password,
}) async {
  final res = await api.post('/auth/login', body: {
    'email': email,
    'password': password,
  });

  final token = res['token'] as String?;
  if (token != null && token.isNotEmpty) {
    await saveToken(token);
  }

  final user = res['user'];
  if (user is Map<String, dynamic>) return user;

  return null;
}

  /// Rejestracja — zwraca usera (jeśli jest), nic nie zapisuje poza tokenem.
  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final res = await api.post('/auth/register', body: {
      'email': email,
      'password': password,
      'username': username,
    });

    final token = res['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }

    final user = res['user'];
    if (user is Map<String, dynamic>) return user;

    return null;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await api.get('/auth/me');
    return res;
  }

  Future<void> logout() async => clearToken();
}
