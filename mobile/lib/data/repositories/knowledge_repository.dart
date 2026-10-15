import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/assistant_question.dart';
import '../models/knowledge.dart';

abstract interface class KnowledgeRepository {
  Future<List<DiseaseSummary>> catalogue();
  Future<DiseaseDetail> detail(String slug);
  Future<KnowledgeSearchResult> search(String query);
}

class ApiKnowledgeRepository implements KnowledgeRepository {
  const ApiKnowledgeRepository(this._api);
  final ApiClient _api;
  @override
  Future<List<DiseaseSummary>> catalogue() async {
    final data = (await _api.get('diseases')).data;
    if (data is! Map<String, dynamic> || data['items'] is! List<dynamic>) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final items = (data['items'] as List<dynamic>)
        .map(DiseaseSummary.fromJson)
        .toList();
    if (items.map((item) => item.slug).toSet().length != items.length) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return List.unmodifiable(items);
  }

  @override
  Future<DiseaseDetail> detail(String slug) async {
    if (!validDiseaseSlug(slug)) {
      throw const AppException(AppErrorKind.validation);
    }
    final detail = DiseaseDetail.fromJson(
      (await _api.get('diseases/$slug')).data,
    );
    if (detail.disease.slug != slug) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return detail;
  }

  @override
  Future<KnowledgeSearchResult> search(String query) async =>
      KnowledgeSearchResult.fromJson(
        (await _api.request(
          ApiMethod.post,
          'knowledge/search',
          body: {'query': normalizeAssistantQuestion(query), 'topK': 5},
          // Above Node's bounded 20-second maximum retrieval deadline.
          requestTimeout: const Duration(seconds: 25),
        )).data,
      );
}
