import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/assistant_answer.dart';
import '../models/assistant_question.dart';
import '../models/scan_prediction.dart';
import '../models/scan_record.dart';

class AssistantDatasource {
  const AssistantDatasource(this._api);
  final ApiClient _api;
  bool get hasAuthenticatedSession => _api.hasAuthenticatedSession;

  Future<AssistantAnswer> ask(
    String question, {
    String? diseaseLabel,
    String? knowledgeType,
  }) async {
    final normalized = normalizeAssistantQuestion(question);
    if ((diseaseLabel != null &&
            !ScanPrediction.classLabels.contains(diseaseLabel)) ||
        (knowledgeType != null &&
            !AssistantAnswer.knowledgeTypes.contains(knowledgeType))) {
      throw const AppException(AppErrorKind.validation);
    }
    final answer = await _post(
      'knowledge/ask',
      body: {
        'question': normalized,
        'diseaseLabel': ?diseaseLabel,
        'knowledgeType': ?knowledgeType,
      },
    );
    if (answer.classifierPrediction != null) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return answer;
  }

  Future<AssistantAnswer> explainScan(ScanRecord scan) async {
    if (!hasAuthenticatedSession) {
      throw const AppException(AppErrorKind.authentication);
    }
    if (!_uuid.hasMatch(scan.id)) {
      throw const AppException(AppErrorKind.validation);
    }
    final prediction = scan.prediction;
    if (scan.status != ScanStatus.completed || prediction == null) {
      throw const AppException(AppErrorKind.conflict);
    }
    try {
      AssistantClassifierContext.fromPrediction(prediction);
    } on AppException {
      throw const AppException(AppErrorKind.conflict);
    }
    final answer = await _post(
      'scans/${scan.id}/explanation',
      body: const {},
      authenticated: true,
    );
    if (answer.classifierPrediction?.matches(prediction) != true) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return answer;
  }

  Future<AssistantAnswer> _post(
    String path, {
    required Map<String, Object?> body,
    bool authenticated = false,
  }) async {
    try {
      final response = await _api.request(
        ApiMethod.post,
        path,
        body: body,
        authenticated: authenticated,
        requestTimeout: const Duration(seconds: 40),
      );
      return AssistantAnswer.fromJson(response.data);
    } on AppException catch (error) {
      if (error.statusCode == 504 || error.statusCode == 502) {
        throw AppException(
          error.statusCode == 504
              ? AppErrorKind.timeout
              : AppErrorKind.invalidResponse,
          statusCode: error.statusCode,
          requestId: error.requestId,
        );
      }
      rethrow;
    }
  }

  static final _uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
}
