import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';



class LogService {
  LogService(this._api);
  final ApiClient _api;

  Future<void> saveWorkout(Map<String, dynamic> workoutData) async {
    await _api.post('/log/workout', body: workoutData);
  }

  Future<List<dynamic>> getLoggedExercises() async {
    final res = await _api.get('/log/logged-exercises');
    if (res['data'] is List) return res['data'] as List<dynamic>;
    if (res is List) return res as List<dynamic>;
    return [];
  }

  Future<List<dynamic>> getExerciseHistory(String exerciseCode) async {
    final res = await _api.get('/log/exercise/$exerciseCode');
    if (res['data'] is List) return res['data'] as List<dynamic>;
    if (res is List) return res as List<dynamic>;
    return [];
  }

  
  Future<List<dynamic>> getWorkoutLogs() async {
    final res = await _api.get('/log/workouts');
    // API zwraca tablicę, która jest opakowana jako {'data': [...]}
    if (res['data'] is List) return res['data'] as List<dynamic>;
    if (res is List) return res as List<dynamic>;
    return [];
  }

  Future<Map<String, dynamic>> getWorkoutLogDetails(int logId) async {
    final res = await _api.get('/log/workout/$logId');
    // API zwraca { workout: {...}, exercises: [...] }
    return res as Map<String, dynamic>;
  }
  Future<void> saveWeight(double weight) async {
    await _api.post('/log/weight', body: {'weight': weight});
  }

  Future<Map<String, dynamic>> getLatestLogs(List<String> exerciseCodes) async {
    final res = await _api.post('/log/latest-for-exercises', body: {
      'exerciseCodes': exerciseCodes,
    });
    
    return (res['data'] ?? res) as Map<String, dynamic>; 
  }

  Future<List<dynamic>> getWeightHistory() async {
    final res = await _api.get('/log/weight-history');
    if (res['data'] is List) return res['data'] as List<dynamic>;
    if (res is List) return res as List<dynamic>;
    return [];
  }
}
