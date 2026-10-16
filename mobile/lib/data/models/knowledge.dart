import '../../core/exceptions/app_exception.dart';
import 'assistant_answer.dart';
import 'scan_prediction.dart';

/// Catalogue metadata is separate from the immutable classifier label mapping.
class DiseaseSummary {
  const DiseaseSummary._(
    this.slug,
    this.name,
    this.scientificName,
    this.description,
  );
  final String slug;
  final String name;
  final String? scientificName;
  final String description;

  factory DiseaseSummary.fromJson(Object? value) {
    final data = _object(value);
    final slug = _text(data['slug'], 120);
    if (!validDiseaseSlug(slug)) throw _invalid();
    return DiseaseSummary._(
      slug,
      _text(data['name'], 255),
      data['scientificName'] == null
          ? null
          : _text(data['scientificName'], 255),
      _text(data['description'], 20000, allowEmpty: true),
    );
  }
}

bool validDiseaseSlug(String slug) =>
    slug.length <= 120 && RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug);

class DiseaseDetail {
  DiseaseDetail._(
    this.disease,
    List<KnowledgeSection> sections,
    this.classifierSupported,
    this.growthStages,
    this.severityDescriptors,
    this.metadataSource,
  ) : sections = List.unmodifiable(sections);
  final DiseaseSummary disease;
  final List<KnowledgeSection> sections;
  final bool? classifierSupported;
  final List<String> growthStages, severityDescriptors;
  final AssistantSourceReference? metadataSource;
  factory DiseaseDetail.fromJson(Object? value) {
    final data = _object(value);
    final sections = _list(
      data['sections'],
      200,
    ).map(KnowledgeSection.fromJson).toList();
    if (sections.map((s) => s.documentId).toSet().length != sections.length) {
      throw _invalid();
    }
    final catalogue = data['catalogue'];
    final metadata = catalogue is Map<String, dynamic>
        ? catalogue['applicability']
        : null;
    List<String> strings(String key, int maximum) =>
        metadata is Map<String, dynamic>
        ? _list(
            metadata[key],
            maximum,
          ).map((v) => _text(v, 600)).toList(growable: false)
        : const [];
    if (catalogue != null &&
        (catalogue is! Map<String, dynamic> ||
            catalogue['classifierSupported'] is! bool)) {
      throw _invalid();
    }
    return DiseaseDetail._(
      DiseaseSummary.fromJson(data),
      sections,
      catalogue is Map<String, dynamic>
          ? catalogue['classifierSupported'] as bool
          : null,
      strings('growthStages', 12),
      strings('severityDescriptors', 8),
      metadata is Map<String, dynamic> && metadata['source'] != null
          ? AssistantSourceReference.fromJson(metadata['source'])
          : null,
    );
  }
}

class KnowledgeSection {
  const KnowledgeSection._(
    this.documentId,
    this.documentKey,
    this.version,
    this.knowledgeType,
    this.title,
    this.content,
    this.source,
  );
  final String documentId;
  final String documentKey;
  final int version;
  final String knowledgeType;
  final String title;
  final String content;
  final AssistantSourceReference source;
  factory KnowledgeSection.fromJson(Object? value) {
    final data = _object(value);
    final type = data['knowledgeType'];
    final version = data['documentVersion'];
    if (!AssistantAnswer.knowledgeTypes.contains(type) ||
        version is! int ||
        version < 1 ||
        version > 2147483647) {
      throw _invalid();
    }
    final id = _text(data['documentId'], 36);
    if (!RegExp(
      r'^[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$',
    ).hasMatch(id)) {
      throw _invalid();
    }
    return KnowledgeSection._(
      id,
      _text(data['documentKey'], 160),
      version,
      type as String,
      _text(data['title'], 255),
      _text(data['content'], 500000),
      AssistantSourceReference.fromJson(data['source']),
    );
  }
}

class KnowledgeMatch {
  const KnowledgeMatch._(
    this.section,
    this.chunkId,
    this.diseaseLabel,
    this.similarity,
  );
  final KnowledgeSection section;
  final String chunkId;
  final String diseaseLabel;
  final double similarity;
  // Existing public catalogue slugs; this is navigation, never a model remapping.
  String get diseaseSlug => switch (diseaseLabel) {
    'Common_Rust' => 'common-rust',
    'Gray_Leaf_Spot' => 'gray-leaf-spot',
    'Healthy' => 'healthy',
    'Northern_Corn_Leaf_Blight' => 'northern-corn-leaf-blight',
    _ => throw _invalid(),
  };
  factory KnowledgeMatch.fromJson(Object? value) {
    final data = _object(value);
    final label = data['diseaseLabel'];
    final score = data['similarity'];
    if (!ScanPrediction.classLabels.contains(label) ||
        score is! num ||
        !score.isFinite ||
        score < -1 ||
        score > 1) {
      throw _invalid();
    }
    return KnowledgeMatch._(
      KnowledgeSection.fromJson(data),
      _text(data['chunkId'], 36),
      label as String,
      score.toDouble(),
    );
  }
}

class KnowledgeSearchResult {
  KnowledgeSearchResult._(List<KnowledgeMatch> matches)
    : matches = List.unmodifiable(matches);
  final List<KnowledgeMatch> matches;
  factory KnowledgeSearchResult.fromJson(Object? value) {
    final data = _object(value);
    final matches = _list(
      data['chunks'],
      10,
    ).map(KnowledgeMatch.fromJson).toList();
    if (data['evidencePolicy'] != 'CANDIDATES_ONLY' ||
        data['retrievalVersion'] != 'cosine-exact-v1' ||
        !const ['MATCHES', 'NO_MATCHES'].contains(data['status']) ||
        (data['status'] == 'NO_MATCHES') != matches.isEmpty ||
        matches.map((m) => m.chunkId).toSet().length != matches.length) {
      throw _invalid();
    }
    return KnowledgeSearchResult._(matches);
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) throw _invalid();
  return value;
}

List<dynamic> _list(Object? value, int maximum) {
  if (value is! List<dynamic> || value.length > maximum) throw _invalid();
  return value;
}

String _text(Object? value, int maximum, {bool allowEmpty = false}) {
  if (value is! String ||
      value.length > maximum ||
      value.contains('\u0000') ||
      (!allowEmpty && value.trim().isEmpty)) {
    throw _invalid();
  }
  return value;
}

AppException _invalid() => const AppException(AppErrorKind.invalidResponse);
