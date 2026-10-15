import 'dart:async';
import 'package:maizedoctor/data/models/knowledge.dart';
import 'package:maizedoctor/data/repositories/knowledge_repository.dart';

const slugs = [
  'common-rust',
  'gray-leaf-spot',
  'healthy',
  'northern-corn-leaf-blight',
];
const labels = [
  'Common_Rust',
  'Gray_Leaf_Spot',
  'Healthy',
  'Northern_Corn_Leaf_Blight',
];
Map<String, Object?> summaryJson([String slug = 'healthy']) => {
  'slug': slug,
  'name': labels[slugs.indexOf(slug)].replaceAll('_', ' '),
  'scientificName': null,
  'description': 'Synthetic catalogue description for $slug.',
};
Map<String, Object?> sourceJson() => {
  'url': 'https://extension.example.test/reviewed',
  'title': 'Fixture source',
  'publisher': 'Test extension publisher',
  'authors': ['Fixture reviewer'],
  'publishedAt': '2020-01-01',
  'retrievedAt': '2026-10-15',
  'rights': 'Test-only source metadata.',
};
Map<String, Object?> sectionJson() => {
  'documentId': '12345678-1234-4123-8123-123456789abc',
  'documentKey': 'fixture-overview',
  'documentVersion': 1,
  'knowledgeType': 'OVERVIEW',
  'title': 'Fixture overview',
  'content': 'Synthetic test-only reviewed passage.',
  'source': sourceJson(),
};
Map<String, Object?> detailJson([String slug = 'healthy']) => {
  ...summaryJson(slug),
  'sections': [sectionJson()],
};
Map<String, Object?> searchJson({bool empty = false}) => {
  'status': empty ? 'NO_MATCHES' : 'MATCHES',
  'chunks': empty
      ? []
      : [
          {
            ...sectionJson(),
            'chunkId': '22345678-1234-4123-8123-123456789abc',
            'chunkIndex': 0,
            'diseaseLabel': 'Healthy',
            'similarity': 0.6,
            'metadata': {},
          },
        ],
  'embeddingModel': 'fixture-model',
  'embeddingVersion': 'fixture-v1',
  'embeddingDimensions': 768,
  'retrievalVersion': 'cosine-exact-v1',
  'evidencePolicy': 'CANDIDATES_ONLY',
};

class FakeKnowledgeRepository implements KnowledgeRepository {
  List<DiseaseSummary> items = slugs
      .map((slug) => DiseaseSummary.fromJson(summaryJson(slug)))
      .toList();
  Object? failure;
  Completer<List<DiseaseSummary>>? pendingCatalogue;
  Completer<KnowledgeSearchResult>? pendingSearch;
  Completer<DiseaseDetail>? pendingDetail;
  int catalogueCalls = 0, searchCalls = 0, detailCalls = 0;
  bool emptySearch = false;
  @override
  Future<List<DiseaseSummary>> catalogue() async {
    catalogueCalls++;
    if (failure case final error?) throw error;
    return pendingCatalogue?.future ?? items;
  }

  @override
  Future<DiseaseDetail> detail(String slug) async {
    detailCalls++;
    if (failure case final error?) throw error;
    return pendingDetail?.future ?? DiseaseDetail.fromJson(detailJson(slug));
  }

  @override
  Future<KnowledgeSearchResult> search(String query) async {
    searchCalls++;
    if (failure case final error?) throw error;
    return pendingSearch?.future ??
        KnowledgeSearchResult.fromJson(searchJson(empty: emptySearch));
  }
}
