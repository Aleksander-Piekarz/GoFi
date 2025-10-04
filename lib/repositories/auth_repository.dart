
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api/api_client.dart';

class AuthRepository {
  final ApiClient api;
  AuthRepository(this.api);

  Future<(User, String?)> login({
    required String email,
    required String password,
  }) async {
    final json = await api.post('/login', body: {
      'email': email,
      'password': password,
    });

    final userMap = json['user'];
    if (userMap is! Map<String, dynamic>) {
      throw ApiException('Brak pola "user" w odpowiedzi');
    }

    final user = User.fromJson(userMap);
    final token = (json['token'] ?? json['accessToken'])?.toString();

    await saveSession(user, token: token);

    return (user, token);
  }


  Future<void> saveSession(User user, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJson()));
    if (token == null || token.isEmpty) {
      await prefs.remove('auth_token');
    } else {
      await prefs.setString('auth_token', token);
    }
  }

  Future<(User?, String?)> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    final token = prefs.getString('auth_token');

    if (userStr == null) return (null, token);

    try {
      final map = jsonDecode(userStr) as Map<String, dynamic>;
      return (User.fromJson(map), token);
    } catch (_) {
      await logout();
      return (null, null);
    }
  }

  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user');
  }

  Future<User> fetchCurrentUser() async {
    final json = await api.get('/current_user'); 
    final userMap = json['user'] ?? json;
    if (userMap is! Map<String, dynamic>) {
      throw ApiException('Brak pola "user" w odpowiedzi');
    }
    return User.fromJson(userMap);
  }
}
