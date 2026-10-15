import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/knowledge.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_view_model.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_detail_view_model.dart';
import 'helpers.dart';

void main() {
  test(
    'catalogue loading suppresses duplicate fetch, supports refresh/empty and disposal',
    () async {
      final repo = FakeKnowledgeRepository()..pendingCatalogue = Completer();
      final model = KnowledgeViewModel(repo);
      final pending = model.load();
      expect(model.loading, true);
      await model.load();
      expect(repo.catalogueCalls, 1);
      repo.pendingCatalogue!.complete(repo.items);
      await pending;
      expect(model.items.length, 4);
      repo.pendingCatalogue = null;
      repo.items = [];
      await model.load();
      expect(model.items, isEmpty);
      repo.pendingCatalogue = Completer();
      final late = model.load();
      model.dispose();
      repo.pendingCatalogue!.complete(repo.items);
      await late;
    },
  );
  for (final kind in [
    AppErrorKind.network,
    AppErrorKind.timeout,
    AppErrorKind.server,
  ]) {
    test('catalogue and search $kind recover independently', () async {
      final repo = FakeKnowledgeRepository()..failure = AppException(kind);
      final model = KnowledgeViewModel(repo);
      addTearDown(model.dispose);
      await model.load();
      await model.search('maize scouting');
      expect(model.catalogueError!.kind, kind);
      expect(model.searchError!.kind, kind);
      repo.failure = null;
      await model.load();
      await model.search('maize scouting');
      expect(model.items.length, 4);
      expect(model.result!.matches.length, 1);
      expect(model.searchError, isNull);
    });
  }
  test(
    'search validation, busy guard, clear/stale fence, no results and disposal',
    () async {
      final repo = FakeKnowledgeRepository();
      final model = KnowledgeViewModel(repo);
      await model.search('ab');
      expect(model.searchError!.kind, AppErrorKind.validation);
      expect(repo.searchCalls, 0);
      repo.pendingSearch = Completer();
      final pending = model.search('healthy maize');
      expect(model.searching, true);
      await model.search('maize symptoms');
      expect(repo.searchCalls, 1);
      model.clearSearch();
      repo.pendingSearch!.complete(
        KnowledgeSearchResult.fromJson(searchJson()),
      );
      await pending;
      expect(model.result, isNull);
      expect(model.query, isNull);
      repo.pendingSearch = null;
      repo.emptySearch = true;
      await model.search('maize symptoms');
      expect(model.result!.matches, isEmpty);
      repo.pendingSearch = Completer();
      final late = model.search('maize symptoms');
      model.dispose();
      repo.pendingSearch!.complete(
        KnowledgeSearchResult.fromJson(searchJson()),
      );
      await late;
    },
  );
  test('detail loading, failure/retry, refresh and disposal', () async {
    final repo = FakeKnowledgeRepository()..pendingDetail = Completer();
    final model = KnowledgeDetailViewModel(repo, 'healthy');
    final pending = model.load();
    expect(model.loading, true);
    await model.load();
    expect(repo.detailCalls, 1);
    repo.pendingDetail!.complete(DiseaseDetail.fromJson(detailJson()));
    await pending;
    expect(model.detail!.disease.slug, 'healthy');
    repo.pendingDetail = null;
    repo.failure = const AppException(AppErrorKind.notFound);
    await model.load();
    expect(model.detail, isNull);
    expect(model.error!.kind, AppErrorKind.notFound);
    repo.failure = null;
    await model.load();
    expect(model.detail!.sections.length, 1);
    repo.pendingDetail = Completer();
    final late = model.load();
    model.dispose();
    repo.pendingDetail!.complete(DiseaseDetail.fromJson(detailJson()));
    await late;
    expect(model.detail, isNull);
  });
}
