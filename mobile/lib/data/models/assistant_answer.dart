import '../../core/exceptions/app_exception.dart';
import 'scan_prediction.dart';

enum AssistantAnswerStatus {
  grounded,
  insufficientInformation,
  outOfScope,
  conflictingEvidence,
}

/// The public, versioned generation contract. Evidence text and citations are
/// accepted together; malformed responses never become uncited chat messages.
class AssistantAnswer {
  AssistantAnswer._({
    required this.status,
    required this.reason,
    required this.message,
    required List<AssistantSection> sections,
    required List<AssistantCitation> sources,
    required this.classifierPrediction,
    required List<String> warnings,
    required this.providerUsed,
    required this.generationModel,
    required this.promptVersion,
    required this.contextPolicyVersion,
    required this.reviewSetVersion,
    required this.durationMs,
  }) : sections = List.unmodifiable(sections),
       sources = List.unmodifiable(sources),
       warnings = List.unmodifiable(warnings);

  static const knowledgeTypes = [
    'OVERVIEW',
    'SYMPTOMS',
    'CAUSES',
    'CONDITIONS',
    'MANAGEMENT',
    'PREVENTION',
    'REFERENCES',
  ];

  final AssistantAnswerStatus status;
  final String reason;
  final String message;
  final List<AssistantSection> sections;
  final List<AssistantCitation> sources;
  final AssistantClassifierContext? classifierPrediction;
  final List<String> warnings;
  final bool providerUsed;
  final String generationModel;
  final String promptVersion;
  final String contextPolicyVersion;
  final String reviewSetVersion;
  final double durationMs;

  factory AssistantAnswer.fromJson(Object? value) {
    final data = _object(value, const {
      'status',
      'reason',
      'message',
      'sections',
      'sources',
      'classifierPrediction',
      'warnings',
      'providerUsed',
      'generationModel',
      'promptVersion',
      'contextPolicyVersion',
      'reviewSetVersion',
      'durationMs',
    });
    final status = switch (data['status']) {
      'GROUNDED' => AssistantAnswerStatus.grounded,
      'INSUFFICIENT_INFORMATION' =>
        AssistantAnswerStatus.insufficientInformation,
      'OUT_OF_SCOPE' => AssistantAnswerStatus.outOfScope,
      'CONFLICTING_EVIDENCE' => AssistantAnswerStatus.conflictingEvidence,
      _ => throw _invalid(),
    };
    final reason = _pattern(data['reason'], 80, r'^[A-Z][A-Z0-9_]{0,79}$');
    final sections = _list(
      data['sections'],
      7,
    ).map(AssistantSection._fromJson).toList();
    final sources = _list(
      data['sources'],
      20,
    ).map(AssistantCitation._fromJson).toList();
    final prediction = data['classifierPrediction'] == null
        ? null
        : AssistantClassifierContext.fromJson(data['classifierPrediction']);
    final warnings = _list(
      data['warnings'],
      10,
    ).map((value) => _text(value, 1000)).toList();
    final providerUsed = data['providerUsed'];
    if (providerUsed is! bool ||
        data['promptVersion'] != 'grounded-evidence-selection-v1' ||
        data['contextPolicyVersion'] != 'reviewed-excerpts-v1' ||
        (status == AssistantAnswerStatus.grounded
            ? !providerUsed || sections.isEmpty || sources.isEmpty
            : sections.isNotEmpty || sources.isNotEmpty) ||
        !_unique(sources.map((source) => source.id)) ||
        !_unique(sections.map((section) => section.knowledgeType)) ||
        (prediction?.predictionStatus == ScanPredictionStatus.lowConfidence &&
            warnings.isEmpty)) {
      throw _invalid();
    }
    final available = sources.map((source) => source.id).toSet();
    final used = <String>{};
    for (final section in sections) {
      for (final item in section.items) {
        if (item.sourceIds.any((id) => !available.contains(id))) {
          throw _invalid();
        }
        used.addAll(item.sourceIds);
      }
    }
    if (used.length != available.length) throw _invalid();
    return AssistantAnswer._(
      status: status,
      reason: reason,
      message: _text(data['message'], 2000),
      sections: sections,
      sources: sources,
      classifierPrediction: prediction,
      warnings: warnings,
      providerUsed: providerUsed,
      generationModel: _identifier(data['generationModel']),
      promptVersion: data['promptVersion'] as String,
      contextPolicyVersion: data['contextPolicyVersion'] as String,
      reviewSetVersion: _identifier(data['reviewSetVersion']),
      durationMs: _number(data['durationMs'], maximum: 120000),
    );
  }
}

class AssistantSection {
  AssistantSection._(
    this.knowledgeType,
    this.heading,
    List<AssistantEvidenceItem> items,
  ) : items = List.unmodifiable(items);
  final String knowledgeType;
  final String heading;
  final List<AssistantEvidenceItem> items;

  factory AssistantSection._fromJson(Object? value) {
    final data = _object(value, const {'knowledgeType', 'heading', 'items'});
    if (!AssistantAnswer.knowledgeTypes.contains(data['knowledgeType'])) {
      throw _invalid();
    }
    return AssistantSection._(
      data['knowledgeType'] as String,
      _text(data['heading'], 160),
      _list(
        data['items'],
        10,
        minimum: 1,
      ).map(AssistantEvidenceItem._fromJson).toList(),
    );
  }
}

class AssistantEvidenceItem {
  AssistantEvidenceItem._(this.text, List<String> sourceIds)
    : sourceIds = List.unmodifiable(sourceIds);
  final String text;
  final List<String> sourceIds;
  factory AssistantEvidenceItem._fromJson(Object? value) {
    final data = _object(value, const {'text', 'sourceIds'});
    final ids = _list(
      data['sourceIds'],
      20,
      minimum: 1,
    ).map((id) => _pattern(id, 4, r'^e[1-9][0-9]{0,2}$')).toList();
    if (!_unique(ids)) throw _invalid();
    return AssistantEvidenceItem._(_text(data['text'], 4000), ids);
  }
}

class AssistantCitation {
  AssistantCitation._({
    required this.id,
    required this.documentId,
    required this.documentKey,
    required this.documentVersion,
    required List<String> chunkIds,
    required this.reference,
  }) : chunkIds = List.unmodifiable(chunkIds);
  final String id;
  final String documentId;
  final String documentKey;
  final int documentVersion;
  final List<String> chunkIds;
  final AssistantSourceReference reference;

  factory AssistantCitation._fromJson(Object? value) {
    final data = _object(value, const {
      'id',
      'documentId',
      'documentKey',
      'documentVersion',
      'chunkIds',
      'source',
    });
    final version = data['documentVersion'];
    final chunks = _list(data['chunkIds'], 32, minimum: 1).map(_uuid).toList();
    if (version is! int ||
        version < 1 ||
        version > 2147483647 ||
        !_unique(chunks)) {
      throw _invalid();
    }
    return AssistantCitation._(
      id: _pattern(data['id'], 4, r'^e[1-9][0-9]{0,2}$'),
      documentId: _uuid(data['documentId']),
      documentKey: _pattern(
        data['documentKey'],
        160,
        r'^[a-z0-9][a-z0-9._-]*$',
      ),
      documentVersion: version,
      chunkIds: chunks,
      reference: AssistantSourceReference._fromJson(data['source']),
    );
  }
}

class AssistantSourceReference {
  AssistantSourceReference._({
    required this.url,
    required this.title,
    required this.publisher,
    required List<String> authors,
    required this.publishedAt,
    required this.retrievedAt,
    required this.rights,
  }) : authors = List.unmodifiable(authors);
  final Uri url;
  final String title;
  final String publisher;
  final List<String> authors;
  final DateTime? publishedAt;
  final DateTime retrievedAt;
  final String rights;

  factory AssistantSourceReference._fromJson(Object? value) {
    final data = _object(value, const {
      'url',
      'title',
      'publisher',
      'authors',
      'publishedAt',
      'retrievedAt',
      'rights',
    });
    final url = _text(data['url'], 2048);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        url.codeUnits.any((unit) => unit <= 32 || unit == 127)) {
      throw _invalid();
    }
    return AssistantSourceReference._(
      url: uri,
      title: _text(data['title'], 255),
      publisher: _text(data['publisher'], 255),
      authors: _list(
        data['authors'],
        16,
      ).map((value) => _text(value, 160)).toList(),
      publishedAt: data['publishedAt'] == null
          ? null
          : _date(data['publishedAt']),
      retrievedAt: _date(data['retrievedAt']),
      rights: _text(data['rights'], 1600),
    );
  }
}

/// Classifier context is separate from knowledge evidence. Only these seven
/// persisted fields are accepted, and an explanation must preserve them exactly.
class AssistantClassifierContext {
  const AssistantClassifierContext._({
    required this.predictedClass,
    required this.confidence,
    required this.modelVersion,
    required this.preprocessingVersion,
    required this.predictionStatus,
    required this.uncertaintyReason,
    required this.confidenceThreshold,
  });
  final String predictedClass;
  final double confidence;
  final String modelVersion;
  final String preprocessingVersion;
  final ScanPredictionStatus predictionStatus;
  final ScanUncertaintyReason? uncertaintyReason;
  final double? confidenceThreshold;

  factory AssistantClassifierContext.fromPrediction(
    ScanPrediction prediction,
  ) => AssistantClassifierContext.fromJson({
    'predictedClass': prediction.predictedClass,
    'confidence': prediction.confidence,
    'modelVersion': prediction.modelVersion,
    'preprocessingVersion': prediction.preprocessingVersion,
    'predictionStatus': switch (prediction.predictionStatus) {
      ScanPredictionStatus.confident => 'CONFIDENT',
      ScanPredictionStatus.lowConfidence => 'LOW_CONFIDENCE',
    },
    'uncertaintyReason': switch (prediction.uncertaintyReason) {
      null => null,
      ScanUncertaintyReason.thresholdUnconfigured => 'THRESHOLD_UNCONFIGURED',
      ScanUncertaintyReason.belowValidationThreshold =>
        'BELOW_VALIDATION_THRESHOLD',
    },
    'confidenceThreshold': prediction.confidenceThreshold,
  });

  factory AssistantClassifierContext.fromJson(Object? value) {
    final data = _object(value, const {
      'predictedClass',
      'confidence',
      'modelVersion',
      'preprocessingVersion',
      'predictionStatus',
      'uncertaintyReason',
      'confidenceThreshold',
    });
    final status = switch (data['predictionStatus']) {
      'CONFIDENT' => ScanPredictionStatus.confident,
      'LOW_CONFIDENCE' => ScanPredictionStatus.lowConfidence,
      _ => throw _invalid(),
    };
    final reason = switch (data['uncertaintyReason']) {
      null => null,
      'THRESHOLD_UNCONFIGURED' => ScanUncertaintyReason.thresholdUnconfigured,
      'BELOW_VALIDATION_THRESHOLD' =>
        ScanUncertaintyReason.belowValidationThreshold,
      _ => throw _invalid(),
    };
    final confidence = _number(data['confidence'], maximum: 1);
    final threshold = data['confidenceThreshold'] == null
        ? null
        : _number(data['confidenceThreshold'], maximum: 1);
    final coherent = threshold == null
        ? status == ScanPredictionStatus.lowConfidence &&
              reason == ScanUncertaintyReason.thresholdUnconfigured
        : threshold > 0 &&
              threshold < 1 &&
              (confidence < threshold
                  ? status == ScanPredictionStatus.lowConfidence &&
                        reason == ScanUncertaintyReason.belowValidationThreshold
                  : status == ScanPredictionStatus.confident && reason == null);
    if (!ScanPrediction.classLabels.contains(data['predictedClass']) ||
        !coherent) {
      throw _invalid();
    }
    return AssistantClassifierContext._(
      predictedClass: data['predictedClass'] as String,
      confidence: confidence,
      modelVersion: _pattern(
        data['modelVersion'],
        80,
        r'^[A-Za-z0-9][A-Za-z0-9._-]*$',
      ),
      preprocessingVersion: _pattern(
        data['preprocessingVersion'],
        120,
        r'^[A-Za-z0-9][A-Za-z0-9._-]*$',
      ),
      predictionStatus: status,
      uncertaintyReason: reason,
      confidenceThreshold: threshold,
    );
  }

  bool matches(ScanPrediction prediction) =>
      predictedClass == prediction.predictedClass &&
      confidence == prediction.confidence &&
      modelVersion == prediction.modelVersion &&
      preprocessingVersion == prediction.preprocessingVersion &&
      predictionStatus == prediction.predictionStatus &&
      uncertaintyReason == prediction.uncertaintyReason &&
      confidenceThreshold == prediction.confidenceThreshold;
}

Map<String, dynamic> _object(Object? value, Set<String> fields) {
  if (value is! Map<String, dynamic> ||
      value.length != fields.length ||
      !fields.every(value.containsKey)) {
    throw _invalid();
  }
  return value;
}

List<dynamic> _list(Object? value, int maximum, {int minimum = 0}) {
  if (value is! List<dynamic> ||
      value.length < minimum ||
      value.length > maximum) {
    throw _invalid();
  }
  return value;
}

String _text(Object? value, int maximum) {
  if (value is! String || value.length > maximum || value.trim().isEmpty) {
    throw _invalid();
  }
  return value;
}

String _pattern(Object? value, int maximum, String pattern) {
  final text = _text(value, maximum);
  if (!RegExp(pattern).hasMatch(text)) throw _invalid();
  return text;
}

String _identifier(Object? value) =>
    _pattern(value, 160, r'^[A-Za-z0-9][A-Za-z0-9._:/@-]*$');
String _uuid(Object? value) => _pattern(
  value,
  36,
  r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[1-8][a-fA-F0-9]{3}-[89abAB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$',
);
bool _unique(Iterable<String> values) => values.toSet().length == values.length;
double _number(Object? value, {required double maximum}) {
  if (value is! num || !value.isFinite || value < 0 || value > maximum) {
    throw _invalid();
  }
  return value.toDouble();
}

DateTime _date(Object? value) {
  final text = _pattern(value, 10, r'^\d{4}-\d{2}-\d{2}$');
  final date = DateTime.tryParse(text);
  if (date == null ||
      date.year != int.parse(text.substring(0, 4)) ||
      date.month != int.parse(text.substring(5, 7)) ||
      date.day != int.parse(text.substring(8, 10))) {
    throw _invalid();
  }
  return DateTime.utc(date.year, date.month, date.day);
}

AppException _invalid() => const AppException(AppErrorKind.invalidResponse);
