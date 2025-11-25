import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class QuestionnaireService {
  // Wstrzykujemy storage w konstruktorze (wymaga zmiany w providers.dart, którą zrobiliśmy w kroku 2)
  QuestionnaireService(this._api, this._storage);
  
  final ApiClient _api;
  final FlutterSecureStorage _storage;
  
  // Klucz, pod którym zapiszemy plan w pamięci telefonu
  static const String _planCacheKey = 'cached_user_plan';

  Future<List<dynamic>> getQuestions() async {
    final res = await _api.get('/questionnaire');
    final obj = res['data'] ?? res; 
    if (obj is List) return obj.cast<dynamic>();
    throw const ApiException('Nieoczekiwany kształt odpowiedzi dla /questionnaire');
  }

  Future<Map<String, dynamic>> getLatestAnswers() async {
    final res = await _api.get('/questionnaire/answers/latest');
    final obj = res['data'] ?? res;
    if (obj is Map) {
      return Map<String, dynamic>.from(obj);
    }
    return <String, dynamic>{};
  }

  Future<void> saveAnswers(Map<String, dynamic> answers) async {
    await _api.post('/questionnaire/answers', body: answers);
  }

  Future<Map<String, dynamic>> submitAndGetPlan(Map<String, dynamic> answers) async {
    final res = await _api.post('/questionnaire/submit', body: answers);
    final obj = res['data'] ?? res;
    final plan = Map<String, dynamic>.from(obj as Map);
    
    // Sukces - zapisujemy nowy plan w pamięci telefonu
    await _cachePlan(plan);
    
    return plan;
  }

  // --- NOWOŚĆ: Pobieranie z obsługą offline ---
  Future<Map<String, dynamic>> getLatestPlan() async {
    try {
      // 1. Próba pobrania z internetu (najświeższa wersja)
      final res = await _api.get('/questionnaire/plan/latest');
      final obj = res['data'] ?? res;
      final plan = Map<String, dynamic>.from(obj as Map);

      // 2. Jeśli pobrano poprawnie i plan nie jest pusty, aktualizujemy cache
      if (plan.isNotEmpty) {
        await _cachePlan(plan);
      }
      
      return plan;
    } catch (e) {
      // 3. W przypadku błędu (np. brak internetu), próbujemy wczytać z pamięci
      print('Błąd sieci: $e. Próba wczytania planu z pamięci urządzenia...');
      final cached = await _loadCachedPlan();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      // Jeśli nie ma sieci I nie ma cache (np. pierwsze uruchomienie), rzucamy błąd dalej
      rethrow;
    }
  }

  // Metoda pomocnicza do zapisu
  Future<void> _cachePlan(Map<String, dynamic> plan) async {
    try {
      // Serializujemy mapę do JSON string i szyfrujemy (SecureStorage)
      await _storage.write(key: _planCacheKey, value: jsonEncode(plan));
    } catch (e) {
      print('Błąd zapisu cache planu: $e');
    }
  }

  // Metoda pomocnicza do odczytu
  Future<Map<String, dynamic>?> _loadCachedPlan() async {
    try {
      final jsonStr = await _storage.read(key: _planCacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Błąd odczytu cache planu: $e');
    }
    return null;
  }
}