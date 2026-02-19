import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'log_service.dart';
import 'questionnaire_service.dart';
import 'exercise_service.dart';
import 'app_version_service.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  String baseUrl = const String.fromEnvironment('API_BASE');

  if (baseUrl.isEmpty) {
    
    //   baseUrl = 'http://localhost:3000/api';
    // } else if (Platform.isAndroid) {
    //   baseUrl = 'http://10.0.2.2:3000/api';
    // } else if (Platform.isIOS || Platform.isMacOS) {
    //   baseUrl = 'http://127.0.0.1:3000/api';
    // } else if (Platform.isWindows || Platform.isLinux) {
    //   baseUrl = 'http://localhost:3000/api';
    // } else {
    //   baseUrl = 'http://192.168.1.X:3000/api';
    // 
    baseUrl = 'https://gofi-app.duckdns.org/api';
  }

  Future<String?> getAuthToken() async => ref.read(authTokenProvider);

  return ApiClient(
    baseUrl: baseUrl,
    getAuthToken: getAuthToken,
    onUnauthorized: () async {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'token');
      ref.read(authTokenProvider.notifier).state = null;
    },
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthService(api: api, storage: storage, tokenProvider: ref);
});

final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authTokenProvider);
  final auth = ref.read(authServiceProvider);
  if (ref.read(authTokenProvider) != null) {
    return auth.me();
  }
  return {}; 
});

final logServiceProvider = Provider<LogService>((ref) {
  final api = ref.read(apiClientProvider);
  return LogService(api);
});

final loggedExercisesProvider = FutureProvider<List<dynamic>>((ref) async {
  ref.watch(authTokenProvider);
  if (ref.read(authTokenProvider) == null) return [];
  return ref.read(logServiceProvider).getLoggedExercises();
});

final exerciseHistoryProvider = FutureProvider.family<List<dynamic>, String>((ref, exerciseCode) async {
  ref.watch(authTokenProvider);
  if (ref.read(authTokenProvider) == null) return [];
  return ref.read(logServiceProvider).getExerciseHistory(exerciseCode);
});

final workoutLogsProvider = FutureProvider<List<dynamic>>((ref) async {
  ref.watch(authTokenProvider);
  if (ref.read(authTokenProvider) == null) return [];
  return ref.read(logServiceProvider).getWorkoutLogs();
});

final workoutLogDetailsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, logId) async {
  ref.watch(authTokenProvider);
  if (ref.read(authTokenProvider) == null) return {};
  return ref.read(logServiceProvider).getWorkoutLogDetails(logId);
});

final questionnaireServiceProvider = Provider<QuestionnaireService>((ref) {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(secureStorageProvider);
  return QuestionnaireService(api, storage);
});

final exerciseServiceProvider = Provider<ExerciseService>((ref) {
  final api = ref.read(apiClientProvider);
  return ExerciseService(api);
});

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  final api = ref.read(apiClientProvider);
  return AppVersionService(api: api);
});

final updateCheckProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  final service = ref.read(appVersionServiceProvider);
  return service.checkForUpdate();
});

final latestLogsProvider = FutureProvider.family<Map<String, dynamic>, List<String>>(
  (ref, exerciseCodes) async {
    if (exerciseCodes.isEmpty) return {};
    return ref.read(logServiceProvider).getLatestLogs(exerciseCodes);
  }
);

final weightHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  ref.watch(authTokenProvider);
  if (ref.read(authTokenProvider) == null) return [];
  return ref.read(logServiceProvider).getWeightHistory();
});

final todayWeightLoggedProvider = FutureProvider<bool>((ref) async {
  final history = await ref.watch(weightHistoryProvider.future);
  if (history.isEmpty) return false;
  
  final today = DateTime.now();
  for (final entry in history) {
    final dateStr = entry['date_logged']?.toString();
    if (dateStr != null) {
      final date = DateTime.parse(dateStr);
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        return true;
      }
    }
  }
  return false;
});