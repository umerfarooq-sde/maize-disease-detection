import 'dart:async';
import 'package:maizedoctor/data/models/assistant_answer.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/data/repositories/assistant_repository.dart';
import '../scans/helpers.dart' show predictionJson;

Map<String, Object?> classifierJson() {
  final prediction = predictionJson();
  return {
    for (final field in [
      'predictedClass',
      'confidence',
      'modelVersion',
      'preprocessingVersion',
      'predictionStatus',
      'uncertaintyReason',
      'confidenceThreshold',
    ])
      field: prediction[field],
  };
}

Map<String, Object?> answerJson({
  String status = 'GROUNDED',
  Map<String, Object?>? classifier,
}) => {
  'status': status,
  'reason': status == 'GROUNDED' ? 'EVIDENCE_SELECTED' : 'NO_EVIDENCE',
  'message': status == 'GROUNDED'
      ? 'Reviewed educational evidence.'
      : 'The available reviewed knowledge cannot support an answer.',
  'sections': status == 'GROUNDED'
      ? [
          {
            'knowledgeType': 'SYMPTOMS',
            'heading': 'Symptoms',
            'items': [
              {
                'text': 'Synthetic reviewed test paragraph.',
                'sourceIds': ['e1'],
              },
            ],
          },
        ]
      : [],
  'sources': status == 'GROUNDED'
      ? [
          {
            'id': 'e1',
            'documentId': '00000000-0000-4000-8000-000000000002',
            'documentKey': 'fixture-reviewed-symptoms',
            'documentVersion': 1,
            'chunkIds': ['00000000-0000-4000-8000-000000000003'],
            'source': {
              'url': 'https://extension.example.test/maize',
              'title': 'Reviewed maize reference',
              'publisher': 'Synthetic extension fixture',
              'authors': ['Fixture author'],
              'publishedAt': null,
              'retrievedAt': '2026-10-12',
              'rights': 'Synthetic metadata for tests only.',
            },
          },
        ]
      : [],
  'classifierPrediction': classifier,
  'warnings': classifier?['predictionStatus'] == 'LOW_CONFIDENCE'
      ? [
          'This model prediction is uncertain; a confidence threshold is not approved.',
        ]
      : ['Educational information; seek qualified local agricultural advice.'],
  'providerUsed': status == 'GROUNDED',
  'generationModel': 'fixture-generation-model',
  'promptVersion': 'grounded-evidence-selection-v1',
  'contextPolicyVersion': 'reviewed-excerpts-v1',
  'reviewSetVersion': 'fixture-review-set',
  'durationMs': 18.25,
};

AssistantAnswer assistantAnswer({
  String status = 'GROUNDED',
  Map<String, Object?>? classifier,
}) => AssistantAnswer.fromJson(
  answerJson(status: status, classifier: classifier),
);

class FakeAssistantRepository implements AssistantRepository {
  @override
  bool hasAuthenticatedSession = false;
  final asks =
      <({String question, String? diseaseLabel, String? knowledgeType})>[];
  final scans = <ScanRecord>[];
  final responses = <Future<AssistantAnswer>>[];
  @override
  Future<AssistantAnswer> ask(
    String question, {
    String? diseaseLabel,
    String? knowledgeType,
  }) {
    asks.add((
      question: question,
      diseaseLabel: diseaseLabel,
      knowledgeType: knowledgeType,
    ));
    return responses.isEmpty
        ? Future.value(assistantAnswer())
        : responses.removeAt(0);
  }

  @override
  Future<AssistantAnswer> explainScan(ScanRecord scan) {
    scans.add(scan);
    return responses.isEmpty
        ? Future.value(assistantAnswer(classifier: classifierJson()))
        : responses.removeAt(0);
  }
}
