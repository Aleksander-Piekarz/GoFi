import 'dart:io'; // <-- Dodaj ten import
import 'package:flutter/foundation.dart'; // <-- Dodaj ten import (dla kIsWeb)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'log_service.dart';
import 'questionnaire_service.dart'; 

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  // 1. Sprawdzamy czy adres został podany przy kompilacji (--dart-define)
  // Jeśli nie, dobieramy go dynamicznie w zależności od urządzenia.
  String baseUrl = const String.fromEnvironment('API_BASE');

if (baseUrl.isEmpty) {
    if (kIsWeb) {
      baseUrl = 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      // Emulator Androida -> 10.0.2.2 to "localhost" komputera
      baseUrl = 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS || Platform.isMacOS) {
      // iOS/Mac -> localhost
      baseUrl = 'http://127.0.0.1:3000/api';
    } else if (Platform.isWindows || Platform.isLinux) {
      // Windows/Linux -> localhost
      baseUrl = 'http://localhost:3000/api'; 
    } else {
      // Fallback (np. fizyczne urządzenie) - tu wpisz swoje IP z ipconfig, jeśli testujesz na telefonie
      baseUrl = 'http://192.168.1.X:3000/api'; 
    }
  }

  Future<String?> getAuthToken() async => ref.read(authTokenProvider);

  return ApiClient(
    baseUrl: baseUrl,
    getAuthToken: getAuthToken,
    onUnauthorized: () async {
      print("Błąd 401: Wylogowywanie użytkownika...");
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

final workoutLogDetailsProvider = FutureProvider.family<List<dynamic>, int>((ref, logId) async {
  ref.watch(authTokenProvider);
  if (ref.read(authTokenProvider) == null) return [];
  return ref.read(logServiceProvider).getWorkoutLogDetails(logId);
});

final questionnaireServiceProvider = Provider<QuestionnaireService>((ref) {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(secureStorageProvider); // <-- Dodano
  return QuestionnaireService(api, storage);
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