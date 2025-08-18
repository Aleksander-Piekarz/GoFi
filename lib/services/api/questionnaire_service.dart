import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class QuestionnaireService {
  static const String _baseUrl = 'http://10.0.2.2:3000';

  static Future<Map<String, dynamic>?> getStatus(String userId) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/questionnaire');
    final r = await http.get(uri).timeout(const Duration(seconds: 10));

    if (r.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(r.body));
    }
    if (r.statusCode == 404) return null;

    debugPrint('GET status error: ${r.statusCode} ${r.body}');
    throw Exception('Server error ${r.statusCode}');
  }

  static Future<Map<String, dynamic>> upsert(String userId, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/questionnaire');
    final payload = Map<String, dynamic>.from(data)..remove('id');

    final r = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 10));

    if (r.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(r.body));
    }
    debugPrint('PUT upsert error: ${r.statusCode} ${r.body}');
    throw Exception('Server error ${r.statusCode}');
  }

  static Future<Map<String, dynamic>> submit(String userId) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/questionnaire/submit');
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    // UWAGA: {} musi mieć jawny typ
    final Map<String, dynamic> body =
        r.body.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(r.body)) : <String, dynamic>{};

    if (r.statusCode == 200) return body;        // { message: ... }
    if (r.statusCode == 400) return body;        // { error: 'Ankieta niekompletna', missing: [...] }
    if (r.statusCode == 404) return body;        // { error: 'Brak ankiety' }

    debugPrint('POST submit e rror: ${r.statusCode} ${r.body}');
    throw Exception('Server error ${r.statusCode}');
  }
}
