import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'questionnaire_service.dart';
import '../../repositories/auth_repository.dart';
const String kBaseUrl = 'http://10.0.2.2:3000';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: kBaseUrl,
    getAuthToken: () async => ref.read(authTokenProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthService(api);
});

final questionnaireServiceProvider = Provider<QuestionnaireService>((ref) {
  final api = ref.watch(apiClientProvider);
  return QuestionnaireService(api);
});



final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthRepository(api);
});