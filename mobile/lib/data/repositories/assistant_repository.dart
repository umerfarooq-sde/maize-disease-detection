import '../datasources/assistant_datasource.dart';
import '../models/assistant_answer.dart';
import '../models/scan_record.dart';

abstract interface class AssistantRepository {
  bool get hasAuthenticatedSession;
  Future<AssistantAnswer> ask(
    String question, {
    String? diseaseLabel,
    String? knowledgeType,
  });
  Future<AssistantAnswer> explainScan(ScanRecord scan);
}

class ApiAssistantRepository implements AssistantRepository {
  const ApiAssistantRepository(this._remote);
  final AssistantDatasource _remote;
  @override
  bool get hasAuthenticatedSession => _remote.hasAuthenticatedSession;
  @override
  Future<AssistantAnswer> ask(
    String question, {
    String? diseaseLabel,
    String? knowledgeType,
  }) => _remote.ask(
    question,
    diseaseLabel: diseaseLabel,
    knowledgeType: knowledgeType,
  );
  @override
  Future<AssistantAnswer> explainScan(ScanRecord scan) =>
      _remote.explainScan(scan);
}
