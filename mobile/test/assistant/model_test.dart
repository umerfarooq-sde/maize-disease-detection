import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/assistant_answer.dart';
import 'package:maizedoctor/data/models/assistant_question.dart';
import 'package:maizedoctor/data/models/scan_prediction.dart';
import '../scans/helpers.dart' show predictionJson;
import 'helpers.dart';

Map<String, dynamic> jsonCopy({Map<String, Object?>? classifier}) =>
    jsonDecode(jsonEncode(answerJson(classifier: classifier)))
        as Map<String, dynamic>;
Matcher invalidResponse() => throwsA(
  isA<AppException>().having(
    (error) => error.kind,
    'kind',
    AppErrorKind.invalidResponse,
  ),
);

void main() {
  test(
    'grounded answers preserve immutable evidence and source provenance',
    () {
      final raw = jsonCopy();
      final answer = AssistantAnswer.fromJson(raw);
      expect(answer.status, AssistantAnswerStatus.grounded);
      expect(answer.sections.single.items.single.sourceIds, ['e1']);
      expect(answer.sources.single.reference.url.scheme, 'https');
      expect(
        answer.sources.single.reference.publisher,
        'Synthetic extension fixture',
      );
      expect(answer.sources.single.reference.publishedAt, null);
      expect(
        answer.sources.single.reference.retrievedAt,
        DateTime.utc(2026, 10, 12),
      );
      expect(answer.generationModel, 'fixture-generation-model');
      expect(answer.durationMs, 18.25);
      (raw['warnings'] as List).clear();
      (raw['sections'] as List).clear();
      expect(answer.sections, hasLength(1));
      expect(answer.warnings, isNotEmpty);
      for (final list in <List<dynamic>>[
        answer.sections,
        answer.sources,
        answer.warnings,
        answer.sections.single.items,
        answer.sections.single.items.single.sourceIds,
        answer.sources.single.chunkIds,
        answer.sources.single.reference.authors,
      ]) {
        expect(() => list.clear(), throwsUnsupportedError);
      }
    },
  );

  test(
    'abstentions are deliberate answers with no factual sections or citations',
    () {
      for (final status in [
        'INSUFFICIENT_INFORMATION',
        'OUT_OF_SCOPE',
        'CONFLICTING_EVIDENCE',
      ]) {
        final answer = assistantAnswer(status: status);
        expect(answer.status, isNot(AssistantAnswerStatus.grounded));
        expect(answer.sections, isEmpty);
        expect(answer.sources, isEmpty);
        expect(answer.providerUsed, false);
      }
    },
  );

  final malformed = <String, void Function(Map<String, dynamic>)>{
    'unknown top-level fields': (data) => data['privatePrompt'] = 'hidden',
    'missing policy': (data) => data.remove('contextPolicyVersion'),
    'unknown status': (data) => data['status'] = 'GUARANTEED_DIAGNOSIS',
    'unchecked paraphrase policy': (data) =>
        data['contextPolicyVersion'] = 'free-chat-v2',
    'grounded without provider': (data) => data['providerUsed'] = false,
    'non-grounded factual text': (data) => data['status'] = 'OUT_OF_SCOPE',
    'unresolved citation': (data) =>
        data['sections'][0]['items'][0]['sourceIds'] = ['e2'],
    'repeated citation': (data) =>
        data['sections'][0]['items'][0]['sourceIds'] = ['e1', 'e1'],
    'unreferenced evidence': (data) => data['sections'][0]['items'] = [],
    'duplicate source identity': (data) =>
        data['sources'].add(data['sources'][0]),
    'repeated chunk identity': (data) =>
        data['sources'][0]['chunkIds'].add(data['sources'][0]['chunkIds'][0]),
    'unknown topic': (data) =>
        data['sections'][0]['knowledgeType'] = 'FERTILIZER_RATE',
    'unexpected item field': (data) =>
        data['sections'][0]['items'][0]['internalPath'] = '/private',
    'source URL with credentials': (data) =>
        data['sources'][0]['source']['url'] =
            'https://user:password@example.test',
    'non-HTTPS source': (data) =>
        data['sources'][0]['source']['url'] = 'javascript:alert(1)',
    'malformed calendar date': (data) =>
        data['sources'][0]['source']['retrievedAt'] = '2026-02-30',
    'private source fields': (data) =>
        data['sources'][0]['source']['apiKey'] = 'secret',
    'nonfinite duration': (data) => data['durationMs'] = double.nan,
    'oversized paragraphs': (data) =>
        data['sections'][0]['items'][0]['text'] = 'x' * 4001,
  };
  for (final entry in malformed.entries) {
    test('rejects ${entry.key}', () {
      final data = jsonCopy();
      entry.value(data);
      expect(() => AssistantAnswer.fromJson(data), invalidResponse());
    });
  }

  test(
    'classifier context preserves all seven fields and honest uncertainty',
    () {
      final prediction = ScanPrediction.fromJson(predictionJson());
      final answer = assistantAnswer(classifier: classifierJson());
      expect(answer.classifierPrediction!.matches(prediction), true);
      expect(
        answer.classifierPrediction!.predictionStatus,
        ScanPredictionStatus.lowConfidence,
      );
      expect(answer.classifierPrediction!.confidenceThreshold, null);
      expect(answer.warnings, isNotEmpty);
      expect(
        AssistantClassifierContext.fromPrediction(
          prediction,
        ).matches(prediction),
        true,
      );
    },
  );

  test(
    'rejects incoherent classifier data and suppression of low-confidence warnings',
    () {
      for (final changes in <String, Object?>{
        'predictedClass': 'Unlisted_Disease',
        'confidence': 1.1,
        'modelVersion': '/private/checkpoint.pt',
        'preprocessingVersion': 'bad version',
        'predictionStatus': 'CONFIDENT',
        'uncertaintyReason': null,
        'confidenceThreshold': 0,
        'secretField': 'injected',
      }.entries) {
        final raw = jsonCopy(
          classifier: {...classifierJson(), changes.key: changes.value},
        );
        expect(() => AssistantAnswer.fromJson(raw), invalidResponse());
      }
      final raw = jsonCopy(classifier: classifierJson())..['warnings'] = [];
      expect(() => AssistantAnswer.fromJson(raw), invalidResponse());
    },
  );

  test('Unicode question limits match code-point and UTF-8 backend bounds', () {
    expect(
      normalizeAssistantQuestion('\u0085  Maize symptoms? \u0085'),
      'Maize symptoms?',
    );
    expect(normalizeAssistantQuestion('🌽' * 450).runes.length, 450);
    expect(normalizeAssistantQuestion('x' * 1000).length, 1000);
    expect(
      normalizeAssistantQuestion('Maize\nsymptoms\tplease'),
      'Maize\nsymptoms\tplease',
    );
    for (final invalid in [
      '',
      '  xx ',
      'x' * 1001,
      '🌽' * 451,
      'bad\u0000data',
      'bad\u000Ddata',
      '\uD800xx',
    ]) {
      expect(
        () => normalizeAssistantQuestion(invalid),
        throwsA(
          isA<AppException>().having(
            (error) => error.kind,
            'kind',
            AppErrorKind.validation,
          ),
        ),
      );
    }
  });
}
