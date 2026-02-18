import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'providers.dart';

/// Typy aktywności treningowej
enum ActivityType { preparation, training, rest, cooldown }

/// Stan pojedynczej aktywności
class WorkoutActivity {
  final int? id;
  final ActivityType type;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  WorkoutActivity({
    this.id,
    required this.type,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.isActive = false,
    this.metadata,
  });

  factory WorkoutActivity.fromJson(Map<String, dynamic> json) {
    return WorkoutActivity(
      id: json['id'],
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['activity_type'],
        orElse: () => ActivityType.training,
      ),
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      durationSeconds: json['duration_seconds'] ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      metadata: json['metadata'] != null 
        ? (json['metadata'] is String ? jsonDecode(json['metadata']) : json['metadata'])
        : null,
    );
  }

  String? get exerciseCode => metadata?['exercise_code'];
  String? get exerciseName => metadata?['exercise_name'];
  int? get setNumber => metadata?['set_number'];
  int? get reps => metadata?['reps'];
  double? get weight => metadata?['weight'] != null 
    ? double.tryParse(metadata!['weight'].toString()) 
    : null;
}

/// Stan sesji treningowej
class WorkoutSession {
  final int id;
  final String? planName;
  final DateTime startedAt;
  final String status;
  final List<WorkoutActivity> activities;
  final WorkoutActivity? currentActivity;

  WorkoutSession({
    required this.id,
    this.planName,
    required this.startedAt,
    required this.status,
    this.activities = const [],
    this.currentActivity,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json, List<dynamic> activitiesJson) {
    final activities = activitiesJson
        .map((a) => WorkoutActivity.fromJson(a as Map<String, dynamic>))
        .toList();
    
    return WorkoutSession(
      id: json['id'],
      planName: json['plan_name'],
      startedAt: DateTime.parse(json['started_at']),
      status: json['status'] ?? 'in_progress',
      activities: activities,
      currentActivity: activities.where((a) => a.isActive).firstOrNull,
    );
  }

  /// Oblicz całkowity czas treningu (tylko training)
  int get totalTrainingSeconds {
    return activities
        .where((a) => a.type == ActivityType.training)
        .fold(0, (sum, a) => sum + _getActivityDuration(a));
  }

  /// Oblicz całkowity czas odpoczynku
  int get totalRestSeconds {
    return activities
        .where((a) => a.type == ActivityType.rest)
        .fold(0, (sum, a) => sum + _getActivityDuration(a));
  }

  /// Oblicz czas przygotowania
  int get totalPreparationSeconds {
    return activities
        .where((a) => a.type == ActivityType.preparation)
        .fold(0, (sum, a) => sum + _getActivityDuration(a));
  }

  /// Oblicz czas rozgrzewki/cooldown
  int get totalCooldownSeconds {
    return activities
        .where((a) => a.type == ActivityType.cooldown)
        .fold(0, (sum, a) => sum + _getActivityDuration(a));
  }

  /// Całkowity czas sesji
  int get totalSessionSeconds {
    return DateTime.now().difference(startedAt).inSeconds;
  }

  int _getActivityDuration(WorkoutActivity a) {
    if (a.isActive) {
      return DateTime.now().difference(a.startTime).inSeconds;
    }
    return a.durationSeconds;
  }

  /// Statystyki per ćwiczenie
  Map<String, ExerciseSessionStats> get exerciseStats {
    final stats = <String, ExerciseSessionStats>{};
    
    for (final a in activities.where((a) => a.type == ActivityType.training && a.exerciseCode != null)) {
      final code = a.exerciseCode!;
      if (!stats.containsKey(code)) {
        stats[code] = ExerciseSessionStats(
          exerciseCode: code,
          exerciseName: a.exerciseName ?? code,
        );
      }
      stats[code]!.addSet(SetStats(
        setNumber: a.setNumber ?? 0,
        durationSeconds: _getActivityDuration(a),
        reps: a.reps,
        weight: a.weight,
      ));
    }
    
    return stats;
  }
}

class ExerciseSessionStats {
  final String exerciseCode;
  final String exerciseName;
  final List<SetStats> sets = [];

  ExerciseSessionStats({required this.exerciseCode, required this.exerciseName});

  void addSet(SetStats set) => sets.add(set);

  int get totalDuration => sets.fold(0, (sum, s) => sum + s.durationSeconds);
  int get setCount => sets.length;
  double get avgSetDuration => setCount > 0 ? totalDuration / setCount : 0;
}

class SetStats {
  final int setNumber;
  final int durationSeconds;
  final int? reps;
  final double? weight;

  SetStats({
    required this.setNumber,
    required this.durationSeconds,
    this.reps,
    this.weight,
  });
}

/// Serwis do zarządzania sesjami treningowymi
class WorkoutSessionService {
  WorkoutSessionService(this._api);
  final ApiClient _api;

  /// Rozpocznij nową sesję lub wznów istniejącą
  Future<WorkoutSession?> startSession({String? planName}) async {
    try {
      final res = await _api.post('/workout/session/start', body: {
        'plan_name': planName,
      });
      
      final sessionId = res['session_id'];
      final activities = res['activities'] as List<dynamic>? ?? [];
      
      return WorkoutSession(
        id: sessionId,
        planName: planName,
        startedAt: DateTime.now(),
        status: 'in_progress',
        activities: activities.map((a) => WorkoutActivity.fromJson(a)).toList(),
      );
    } catch (e) {
      print('Error starting session: $e');
      return null;
    }
  }

  /// Pobierz aktualną aktywną sesję (do wznowienia po powrocie do app)
  Future<WorkoutSession?> getCurrentSession() async {
    try {
      final res = await _api.get('/workout/session/current');
      
      if (res['active'] != true) return null;
      
      final session = res['session'] as Map<String, dynamic>;
      final activities = res['activities'] as List<dynamic>? ?? [];
      
      return WorkoutSession.fromJson(session, activities);
    } catch (e) {
      print('Error getting current session: $e');
      return null;
    }
  }

  /// Rozpocznij serię ćwiczenia
  Future<bool> startSet({
    required int sessionId,
    required String exerciseCode,
    required String exerciseName,
    required int setNumber,
  }) async {
    try {
      await _api.post('/workout/session/set/start', body: {
        'session_id': sessionId,
        'exercise_code': exerciseCode,
        'exercise_name': exerciseName,
        'set_number': setNumber,
      });
      return true;
    } catch (e) {
      print('Error starting set: $e');
      return false;
    }
  }

  /// Zakończ serię i (opcjonalnie) rozpocznij odpoczynek
  Future<bool> endSet({
    required int sessionId,
    int? reps,
    double? weight,
    bool startRest = true,
  }) async {
    try {
      await _api.post('/workout/session/set/end', body: {
        'session_id': sessionId,
        'reps': reps,
        'weight': weight,
        'start_rest': startRest,
      });
      return true;
    } catch (e) {
      print('Error ending set: $e');
      return false;
    }
  }

  /// Zmień fazę (preparation -> training -> cooldown)
  Future<bool> transitionPhase({
    required int sessionId,
    required ActivityType nextType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _api.post('/workout/session/transition', body: {
        'session_id': sessionId,
        'next_type': nextType.name,
        'metadata': metadata,
      });
      return true;
    } catch (e) {
      print('Error transitioning phase: $e');
      return false;
    }
  }

  /// Zakończ sesję
  Future<Map<String, dynamic>?> endSession({
    required int sessionId,
    List<Map<String, dynamic>>? exercises,
  }) async {
    try {
      final res = await _api.post('/workout/session/end', body: {
        'session_id': sessionId,
        'exercises': exercises,
      });
      return res;
    } catch (e) {
      print('Error ending session: $e');
      return null;
    }
  }

  /// Porzuć sesję
  Future<bool> abandonSession(int sessionId) async {
    try {
      await _api.post('/workout/session/abandon', body: {
        'session_id': sessionId,
      });
      return true;
    } catch (e) {
      print('Error abandoning session: $e');
      return false;
    }
  }

  /// Pobierz statystyki
  Future<Map<String, dynamic>?> getStats({String period = 'week'}) async {
    try {
      final res = await _api.get('/workout/session/stats?period=$period');
      return res;
    } catch (e) {
      print('Error getting stats: $e');
      return null;
    }
  }

  /// Pobierz statystyki per ćwiczenie
  Future<Map<String, dynamic>?> getExerciseStats({String period = 'week'}) async {
    try {
      final res = await _api.get('/workout/session/exercise-stats?period=$period');
      return res;
    } catch (e) {
      print('Error getting exercise stats: $e');
      return null;
    }
  }

  /// Heartbeat - utrzymuj sesję przy życiu
  Future<void> heartbeat(int sessionId) async {
    try {
      await _api.post('/workout/session/heartbeat', body: {
        'session_id': sessionId,
      });
    } catch (e) {
      print('Heartbeat error: $e');
    }
  }
}

/// Provider dla WorkoutSessionService
final workoutSessionServiceProvider = Provider<WorkoutSessionService>((ref) {
  final api = ref.read(apiClientProvider);
  return WorkoutSessionService(api);
});

/// Stan aktywnej sesji treningowej (z auto-refresh)
class ActiveWorkoutSessionNotifier extends StateNotifier<WorkoutSession?> {
  ActiveWorkoutSessionNotifier(this._service) : super(null);
  
  final WorkoutSessionService _service;
  Timer? _refreshTimer;
  Timer? _heartbeatTimer;

  /// Załaduj lub wznów sesję
  Future<void> loadOrStartSession({String? planName}) async {
    // Najpierw sprawdź czy jest aktywna sesja
    var session = await _service.getCurrentSession();
    
    // Jeśli nie ma, utwórz nową
    if (session == null) {
      session = await _service.startSession(planName: planName);
    }
    
    state = session;
    
    if (session != null) {
      _startTimers(session.id);
    }
  }

  void _startTimers(int sessionId) {
    // Odśwież stan co sekundę (dla UI timerów)
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Tylko trigger rebuild dla UI, nie fetchuj z serwera
      state = state; // Force rebuild
    });
    
    // Heartbeat co 30 sekund
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _service.heartbeat(sessionId);
      // Przy okazji odśwież stan z serwera
      final fresh = await _service.getCurrentSession();
      if (fresh != null) {
        state = fresh;
      }
    });
  }

  /// Rozpocznij serię
  Future<void> startSet({
    required String exerciseCode,
    required String exerciseName,
    required int setNumber,
  }) async {
    if (state == null) return;
    
    await _service.startSet(
      sessionId: state!.id,
      exerciseCode: exerciseCode,
      exerciseName: exerciseName,
      setNumber: setNumber,
    );
    
    // Odśwież stan
    final fresh = await _service.getCurrentSession();
    if (fresh != null) state = fresh;
  }

  /// Zakończ serię
  Future<void> endSet({int? reps, double? weight, bool startRest = true}) async {
    if (state == null) return;
    
    await _service.endSet(
      sessionId: state!.id,
      reps: reps,
      weight: weight,
      startRest: startRest,
    );
    
    final fresh = await _service.getCurrentSession();
    if (fresh != null) state = fresh;
  }

  /// Zmień fazę
  Future<void> transitionTo(ActivityType phase) async {
    if (state == null) return;
    
    await _service.transitionPhase(
      sessionId: state!.id,
      nextType: phase,
    );
    
    final fresh = await _service.getCurrentSession();
    if (fresh != null) state = fresh;
  }

  /// Zakończ trening
  Future<Map<String, dynamic>?> finishWorkout({List<Map<String, dynamic>>? exercises}) async {
    if (state == null) return null;
    
    final result = await _service.endSession(
      sessionId: state!.id,
      exercises: exercises,
    );
    
    _stopTimers();
    state = null;
    
    return result;
  }

  /// Porzuć trening
  Future<void> abandonWorkout() async {
    if (state == null) return;
    
    await _service.abandonSession(state!.id);
    _stopTimers();
    state = null;
  }

  void _stopTimers() {
    _refreshTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}

final activeWorkoutSessionProvider = 
    StateNotifierProvider<ActiveWorkoutSessionNotifier, WorkoutSession?>((ref) {
  final service = ref.read(workoutSessionServiceProvider);
  return ActiveWorkoutSessionNotifier(service);
});
