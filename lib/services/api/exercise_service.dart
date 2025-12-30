import 'api_client.dart';

class ExerciseService {
  final ApiClient _api;

  ExerciseService(this._api);

  Future<List<Map<String, dynamic>>> getAlternatives(String exerciseCode) async {
    try {
      final res = await _api.get('/exercises/$exerciseCode/alternatives');
      
      // Obsługa, jeśli API zwraca listę bezpośrednio lub w obiekcie {data: ...}
      final List data = (res is Map && res.containsKey('data')) ? res['data'] : res;
      
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Błąd pobierania alternatyw: $e');
      return [];
    }
  }
}