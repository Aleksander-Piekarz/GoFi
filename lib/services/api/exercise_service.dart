import '../../models/exercise.dart';
import 'api_client.dart';

class ExerciseService {
  final ApiClient _api;

  ExerciseService(this._api);

  /// Pobiera alternatywne ćwiczenia
  Future<List<Map<String, dynamic>>> getAlternatives(String exerciseCode) async {
    try {
      final res = await _api.get('/exercises/$exerciseCode/alternatives');
      final List data = (res is Map && res.containsKey('data')) ? res['data'] : res;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Błąd pobierania alternatyw: $e');
      return [];
    }
  }

  /// Pobiera pełne dane ćwiczenia po kodzie
  Future<Exercise?> getExerciseByCode(String code) async {
    try {
      final res = await _api.get('/exercises/$code');
      if (res != null && res is Map<String, dynamic>) {
        return Exercise.fromJson(res);
      }
      return null;
    } catch (e) {
      print('Błąd pobierania ćwiczenia: $e');
      return null;
    }
  }

  /// Pobiera listę wszystkich ćwiczeń (z paginacją)
  Future<List<Exercise>> getAllExercises({
    int page = 1,
    int limit = 50,
    String? muscle,
    String? equipment,
    String? difficulty,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (muscle != null) queryParams['muscle'] = muscle;
      if (equipment != null) queryParams['equipment'] = equipment;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      final res = await _api.get('/exercises?$queryString');
      
      final List data = (res is Map && res.containsKey('data')) ? res['data'] : res;
      return data.map((json) => Exercise.fromJson(json)).toList();
    } catch (e) {
      print('Błąd pobierania listy ćwiczeń: $e');
      return [];
    }
  }

  /// Pobiera listę unikalnych partii mięśniowych
  Future<List<String>> getMuscleGroups() async {
    try {
      final res = await _api.get('/exercises/muscles');
      final List data = (res is Map && res.containsKey('data')) ? res['data'] : res;
      return data.cast<String>();
    } catch (e) {
      print('Błąd pobierania partii mięśniowych: $e');
      return [
        'abs', 'biceps', 'triceps', 'chest', 'back', 'shoulders',
        'quads', 'hamstrings', 'glutes', 'calves', 'forearms'
      ];
    }
  }

  /// Pobiera listę unikalnego sprzętu
  Future<List<String>> getEquipmentTypes() async {
    try {
      final res = await _api.get('/exercises/equipment');
      final List data = (res is Map && res.containsKey('data')) ? res['data'] : res;
      return data.cast<String>();
    } catch (e) {
      print('Błąd pobierania typów sprzętu: $e');
      return [
        'body weight', 'barbell', 'dumbbell', 'cable', 'machine',
        'kettlebell', 'band', 'medicine ball'
      ];
    }
  }

  /// Pobiera ćwiczenia według partii mięśniowej
  Future<List<Exercise>> getExercisesByMuscle(String muscle) async {
    return getAllExercises(muscle: muscle, limit: 100);
  }

  /// Wyszukuje ćwiczenia
  Future<List<Exercise>> searchExercises(String query) async {
    return getAllExercises(search: query, limit: 50);
  }
}