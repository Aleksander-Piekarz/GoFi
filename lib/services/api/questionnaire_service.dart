import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'providers.dart';

final questionnaireServiceProvider = Provider<QuestionnaireService>((ref) {
  final api = ref.read(apiClientProvider);
  return QuestionnaireService(api);
});

class QuestionnaireService {
  QuestionnaireService(this._api);
  final ApiClient _api;

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
  return Map<String, dynamic>.from(obj as Map);
}

Future<Map<String, dynamic>> getLatestPlan() async {
  final res = await _api.get('/questionnaire/plan/latest');
  final obj = res['data'] ?? res;
  return Map<String, dynamic>.from(obj as Map);
}

}
