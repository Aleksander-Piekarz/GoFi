import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  // REJESTRACJA
  static Future<String?> register(String email, String username, String password) async {
    final url = Uri.parse('$baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return null; // brak błędu
      } else {
        return jsonDecode(response.body)['message'] ?? 'Błąd rejestracji';
      }
    } catch (e) {
      return 'Błąd połączenia: $e';
    }
  }

  // LOGOWANIE
  static Future<String?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(response.statusCode);
        print(response.body);
        //zwracamy jeszcze informacje czy questionnaire jest wypełnione
        return data['user']['id'].toString(); // zawsze zwracamy String
        
      } else {
        return null; 
      }
    } catch (e) {
      return null; 
    }
  }
}
