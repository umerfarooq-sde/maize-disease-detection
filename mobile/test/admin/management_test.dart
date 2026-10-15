import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import 'package:maizedoctor/data/repositories/admin_management_repository.dart';
import 'package:maizedoctor/features/admin/view_models/admin_management_view_model.dart';
import '../auth/session_test.dart' show response;

const managementId = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> managementDocument({
  String status = 'DRAFT',
  int version = 1,
}) => {
  'id': managementId,
  'documentKey': 'synthetic-note',
  'version': version,
  'title': 'Synthetic sourced note',
  'status': status,
  'diseaseSlug': 'common-rust',
  'knowledgeType': 'OVERVIEW',
  'indexed': true,
  'content': 'Synthetic contract-only text.',
  'source': {
    'title': 'Synthetic source',
    'publisher': 'Test publisher',
    'url': 'https://example.invalid/source',
    'authors': ['Test author'],
    'publishedAt': null,
    'retrievedAt': '2026-10-01',
    'rights': 'Synthetic test only.',
  },
  'curation': {'region': 'Synthetic scope', 'sourceSection': 'Test section'},
};
ManagementEntry knowledgeEntry({String status = 'DRAFT'}) =>
    ManagementEntry.fromJson(
      managementDocument(status: status),
      ManagementArea.knowledge,
    );

class MemoryManagementRepository implements AdminManagementRepository {
  @override
  bool hasSession = true;
  @override
  int? revision = 1;
  final calls = <String>[];
  AppException? failure;
  Completer<ManagementPage>? pending;
  Map<String, Object?>? saved;
  @override
  Future<ManagementPage> list(ManagementArea area, {String? cursor}) async {
    calls.add('list:${area.name}:$cursor');
    if (failure != null) throw failure!;
    return pending?.future ?? ManagementPage([knowledgeEntry()], null);
  }

  @override
  Future<ManagementEntry> document(String id) async {
    calls.add('detail:$id');
    return knowledgeEntry();
  }

  @override
  Future<void> save(ManagementEditor editor, Map<String, Object?> body) async {
    calls.add('save');
    if (failure != null) throw failure!;
    saved = body;
  }

  @override
  Future<void> index(String id) async {
    calls.add('index:$id');
    if (failure != null) throw failure!;
  }

  @override
  Future<void> status(
    ManagementArea area,
    ManagementEntry entry,
    String status,
  ) async {
    calls.add('status:$status');
  }
}

void main() {
  test(
    'new versions retain fixed series/class/source and require fresh explicit approval',
    () {
      final item = knowledgeEntry();
      final fields = managementEditorValues(ManagementArea.knowledge, item);
      expect(fields['source.url'], 'https://example.invalid/source');
      expect(fields['reviewNote'], '');
      final editor = ManagementEditor(ManagementArea.knowledge, item, fields);
      expect(
        () => managementWrite(editor, fields),
        throwsA(isA<AppException>()),
      );
      final write = managementWrite(editor, {
        ...fields,
        'reviewNote': 'Synthetic reviewed source for this isolated test.',
        'approved': 'true',
      });
      expect(write['expectedVersion'], 1);
      expect(write['diseaseSlug'], 'common-rust');
      expect(write['documentKey'], 'synthetic-note');
      expect(write.containsKey('literalLabel'), false);
      expect(write.containsKey('version'), false);
      expect((write['source']! as Map)['authors'], ['Test author']);
    },
  );
  test(
    'management validation rejects ambiguous decimals, percentages, dates, versions and source URLs',
    () {
      for (final entry in {
        'rate': '1e3',
        'product.nitrogenPercent': '100.01',
        'source.url': 'http://example.invalid',
        'source.retrievedAt': '2026-02-30',
        'version': '-1',
        'quantityDecimalPlaces': '7',
        'documentKey': 'Renamed Label',
        'reviewNote': 'short',
      }.entries) {
        expect(validateManagementField(entry.key, entry.value), isNotNull);
      }
      expect(validateManagementField('rate', '0.000001'), isNull);
      expect(
        validateManagementField('source.publishedAt', '', required: false),
        isNull,
      );
    },
  );
  test(
    'calculator editor builds version-pinned decimal strings without calculating or inventing rates',
    () {
      final fields = <String, String>{
        'approved': 'true',
        'version': '2',
        'rate': '123.125',
        'title': 'Synthetic reviewed scenario',
        'applicability': 'Test only',
        'assumptions': 'Synthetic first\nSynthetic second',
        'source.title': 'Synthetic',
        'source.publisher': 'Test',
        'source.url': 'https://example.invalid',
        'source.citation': 'Synthetic fixture',
        'quantityDecimalPlaces': '3',
        'reviewNote': 'Synthetic review; no recommendation approval.',
      };
      final result = managementWrite(
        ManagementEditor(ManagementArea.yieldRules, null, {}),
        fields,
      );
      expect(result['expectedYieldKgPerHectare'], '123.125');
      expect(result['version'], 2);
      expect(result.containsKey('formula'), false);
      expect(result.containsKey('engineVersion'), false);
      expect(
        managementEditorValues(ManagementArea.yieldRules, null)['rate'],
        '',
      );
    },
  );
  test(
    'Admin repository uses only protected Node paths, body contracts and CAS expected status',
    () async {
      final tokens = MemorySessionTokens()
        ..save('admin.access.token', const Duration(minutes: 10));
      final requests = <http.Request>[];
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: tokens,
        client: MockClient((request) async {
          requests.add(request);
          return response(
            request.url.path.endsWith('/documents')
                ? {
                    'items': [managementDocument()],
                    'nextCursor': null,
                  }
                : managementDocument(),
          );
        }),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      final repository = ApiAdminManagementRepository(api);
      final page = await repository.list(ManagementArea.knowledge);
      expect(page.items.single.version, 1);
      await repository.index(managementId);
      await repository.status(
        ManagementArea.knowledge,
        knowledgeEntry(),
        'ARCHIVED',
      );
      expect(requests.map((request) => request.url.path), [
        '/api/v1/admin/knowledge/documents',
        '/api/v1/admin/knowledge/documents/$managementId/index',
        '/api/v1/admin/knowledge/documents/$managementId/status',
      ]);
      expect(jsonDecode(requests.last.body), {
        'status': 'ARCHIVED',
        'expectedStatus': 'DRAFT',
      });
      expect(
        requests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer admin.access.token',
        ),
        true,
      );
    },
  );
  test(
    'management ViewModel loads, creates new version, rebuilds then reloads, and preserves failed draft edits',
    () async {
      final repository = MemoryManagementRepository();
      final model = AdminManagementViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      await model.edit(model.items.single);
      expect(model.editor!.initial['content'], 'Synthetic contract-only text.');
      repository.failure = const AppException(AppErrorKind.timeout);
      await model.save({...model.editor!.initial, 'approved': 'true'});
      expect(model.editor, isNotNull);
      expect(model.error!.kind, AppErrorKind.timeout);
      repository.failure = null;
      await model.save({...model.editor!.initial, 'approved': 'true'});
      expect(model.editor, isNull);
      expect(repository.saved!['expectedVersion'], 1);
      await model.index(model.items.single);
      expect(repository.calls, contains('index:$managementId'));
      await model.status(model.items.single, 'ACTIVE');
      expect(repository.calls, contains('status:ACTIVE'));
    },
  );
  test(
    'guest/changed Admin sessions never restore private versions or drafts from delayed replies',
    () async {
      final repository = MemoryManagementRepository()..hasSession = false;
      final model = AdminManagementViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      expect(repository.calls, isEmpty);
      repository.hasSession = true;
      await model.load();
      await model.edit(model.items.single);
      expect(model.editor, isNotNull);
      repository.revision = 2;
      expect(model.items, isEmpty);
      expect(model.editor, isNull);
      repository.pending = Completer<ManagementPage>();
      final pending = model.load();
      repository.revision = 3;
      repository.pending!.complete(ManagementPage([knowledgeEntry()], null));
      await pending;
      expect(model.items, isEmpty);
      expect(model.editor, isNull);
    },
  );
}
