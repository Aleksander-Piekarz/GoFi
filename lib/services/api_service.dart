import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:3000'; // Używaj 10.0.2.2 na emulatorze Androida

  // REJESTRACJA
  static Future<String> register(String email,String username, String password) async {
    final url = Uri.parse('$baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email,'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return '';
      } else {
        return jsonDecode(response.body)['message'] ?? 'Błąd rejestracji';
      }
    } catch (e) {
      return 'Błąd połączenia: $e';
    }
  }

  // LOGOWANIE
  static Future<String> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return ''; // Sukces
      } else {
        return jsonDecode(response.body)['message'] ?? 'Błąd logowania';
      }
    } catch (e) {
      return 'Błąd połączenia: $e';
    }
  }
}
