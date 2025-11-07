import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'auth_service.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = const String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.10.0.2:3000/api',
  );
  Future<String?> getAuthToken() async => ref.read(authTokenProvider);
  return ApiClient(baseUrl: baseUrl, getAuthToken: getAuthToken);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthService(api: api, storage: storage, tokenProvider: ref);
});
