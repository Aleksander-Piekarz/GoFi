import 'api_client.dart';

class QuestionnaireService {
  final ApiClient api;
  QuestionnaireService(this.api);

  Future<List<Map<String, dynamic>>> fetchQuestions() async {
    final json = await api.get('/questionnaire/questions');
    final list = (json['data'] ?? json['questions'] ?? []) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> submitAnswers(Map<String, dynamic> payload) async {
    await api.post('/questionnaire/answers', body: payload);
  }
}
