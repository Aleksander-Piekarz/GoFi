import '../../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient api;
  AuthService(this.api);

  Future<(User, String?)> login({
    required String email,
    required String password,
  }) async {
    final json = await api.post('/login', body: {
      'email': email,
      'password': password,
    });

    final String? token = (json['token'] ?? json['accessToken'])?.toString();

    final userMap = json['user'] ?? json;
    if (userMap is! Map<String, dynamic>) {
      throw ApiException('Brak poprawnego pola "user" w odpowiedzi logowania');
    }

    final user = User.fromJson(userMap);
    return (user, token);
  }

  Future<(User, String?)> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final json = await api.post('/register', body: {
      'email': email,
      'password': password,
      'username': username,
    });

    final String? token = (json['token'] ?? json['accessToken'])?.toString();

    final userMap = json['user'] ?? json;
    if (userMap is! Map<String, dynamic>) {
      throw ApiException('Brak poprawnego pola "user" w odpowiedzi rejestracji');
    }

    final user = User.fromJson(userMap);
    return (user, token);
  }

 Future<User> me() async {
    final json = await api.get('/me');
    final userMap = json['user'] ?? json;
    if (userMap is! Map<String, dynamic>) {
      throw ApiException('Brak poprawnego pola "user" w odpowiedzi /me');
    }
    return User.fromJson(userMap);
  }
}
