import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/models/knowledge.dart';
import 'package:maizedoctor/data/repositories/knowledge_repository.dart';
import '../auth/session_test.dart' show response;
import 'helpers.dart';

void main() {
  test(
    'public catalogue/details/search use distinct endpoints and retain four labels and sources',
    () async {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((request) async {
          expect(request.headers['Authorization'], isNull);
          expect(request.url.query, isEmpty);
          if (request.url.path.endsWith('/knowledge/search')) {
            expect(request.method, 'POST');
            expect(jsonDecode(request.body), {
              'query': 'healthy maize scouting',
              'topK': 5,
            });
            return response(searchJson());
          }
          if (request.url.path.endsWith('/diseases')) {
            return response({'items': slugs.map(summaryJson).toList()});
          }
          return response(detailJson(request.url.pathSegments.last));
        }),
      );
      addTearDown(api.close);
      final repo = ApiKnowledgeRepository(api);
      expect((await repo.catalogue()).map((d) => d.slug), slugs);
      for (final slug in slugs) {
        final detail = await repo.detail(slug);
        expect(detail.disease.slug, slug);
        expect(
          detail.sections.single.source.publisher,
          'Test extension publisher',
        );
        expect(detail.sections.single.source.authors, ['Fixture reviewer']);
        expect(detail.sections.single.version, 1);
      }
      final result = await repo.search(' healthy maize scouting ');
      expect(result.matches.single.diseaseLabel, 'Healthy');
      expect(result.matches.single.diseaseSlug, 'healthy');
      expect(result.matches.single.section.source.url.scheme, 'https');
    },
  );
  test('invalid slug and bounded Unicode query rejected before HTTP', () async {
    var calls = 0;
    final api = ApiClient(
      config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
      client: MockClient((_) async {
        calls++;
        return response(null);
      }),
    );
    addTearDown(api.close);
    final repo = ApiKnowledgeRepository(api);
    for (final slug in ['../auth/me', '', 'Healthy', 'healthy?x=1']) {
      await expectLater(repo.detail(slug), throwsA(isA<AppException>()));
    }
    for (final query in ['', 'ab', '🌽' * 451, 'x' * 1001, 'bad\u0000query']) {
      await expectLater(repo.search(query), throwsA(isA<AppException>()));
    }
    expect(calls, 0);
  });
  test('empty catalogue and no matches are valid, not fake content', () async {
    final api = ApiClient(
      config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
      client: MockClient(
        (request) async => response(
          request.method == 'GET' ? {'items': []} : searchJson(empty: true),
        ),
      ),
    );
    addTearDown(api.close);
    final repo = ApiKnowledgeRepository(api);
    expect(await repo.catalogue(), isEmpty);
    expect((await repo.search('maize symptoms')).matches, isEmpty);
  });
  for (final status in [404, 503, 504]) {
    test('detail HTTP $status remains a safe error', () async {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((_) async => response(null, status: status)),
      );
      addTearDown(api.close);
      await expectLater(
        ApiKnowledgeRepository(api).detail('healthy'),
        throwsA(
          isA<AppException>().having((e) => e.statusCode, 'status', status),
        ),
      );
    });
  }
  test(
    'malformed catalogue, mismatched detail, untrusted sources and inconsistent retrieval fail closed',
    () async {
      for (final data in [
        null,
        {'items': 'bad'},
        {
          'items': [summaryJson(), summaryJson()],
        },
      ]) {
        final api = ApiClient(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          client: MockClient((_) async => response(data)),
        );
        await expectLater(
          ApiKnowledgeRepository(api).catalogue(),
          throwsA(isA<AppException>()),
        );
        api.close();
      }
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((_) async => response(detailJson('common-rust'))),
      );
      addTearDown(api.close);
      await expectLater(
        ApiKnowledgeRepository(api).detail('healthy'),
        throwsA(isA<AppException>()),
      );
      expect(
        () => DiseaseDetail.fromJson({
          ...detailJson(),
          'sections': [
            {
              ...sectionJson(),
              'source': {...sourceJson(), 'url': 'javascript:bad'},
            },
          ],
        }),
        throwsA(isA<AppException>()),
      );
      expect(
        () => KnowledgeSearchResult.fromJson({
          ...searchJson(),
          'status': 'NO_MATCHES',
        }),
        throwsA(isA<AppException>()),
      );
      expect(
        () => KnowledgeSearchResult.fromJson({
          ...searchJson(),
          'evidencePolicy': 'CERTAIN',
        }),
        throwsA(isA<AppException>()),
      );
    },
  );
}
