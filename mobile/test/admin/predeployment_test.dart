import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/models/ai_operations.dart';
import 'package:maizedoctor/data/models/knowledge.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import 'package:maizedoctor/data/models/reference_media.dart';
import 'package:maizedoctor/data/repositories/reference_media_repository.dart';
import 'package:maizedoctor/features/admin/widgets/ai_operations_panel.dart';
import 'package:maizedoctor/features/admin/widgets/management_editor_form.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/reference_gallery_view_model.dart';
import '../auth/session_test.dart' show response;
import '../knowledge/helpers.dart' show sourceJson, detailJson;

Map<String, Object?> mediaJson() => {
  'id': '12345678-1234-4123-8123-123456789abc',
  'diseaseSlug': 'healthy',
  'altText': 'Synthetic rectangle, not disease evidence',
  'sortOrder': 0,
  'status': 'ACTIVE',
  'revision': 'a' * 64,
  'imagePath': 'disease-images/12345678-1234-4123-8123-123456789abc/image',
  'updatedAt': '2026-10-16T00:00:00.000Z',
  'provenance': {
    'source': sourceJson(),
    'license': 'Synthetic test use only',
    'contributor': 'Test generator',
    'attribution': 'Synthetic, not disease evidence',
    'rightsConfirmed': true,
    'contentKind': 'SYNTHETIC_TEST',
  },
};
void main() {
  testWidgets(
    'independent product editor renders reviewed optional metadata without inventing rates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManagementEditorForm(
                editor: ManagementEditor(ManagementArea.fertilizers, null, {}),
                busy: false,
                onSave: (_) async {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(
          'Source rate reference (optional text, never a calculation rule)',
        ),
        findsOneWidget,
      );
      expect(find.text('Nitrogen N % by mass'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'standalone product editing preserves explicit nutrient basis and requires fresh source review',
    () {
      final fields = <String, String>{
        'product.slug': 'synthetic-product',
        'product.name': 'Synthetic product',
        'product.description': 'Synthetic, never a recommendation',
        'product.nitrogenPercent': '0',
        'product.phosphorusPercent': '0',
        'product.potassiumPercent': '0',
        'source.url': 'https://example.invalid/product',
        'source.title': 'Synthetic source',
        'source.publisher': 'Test generator',
        'source.citation': 'Synthetic source only',
        'reviewNote': 'Source intake review for generated fixture only.',
        'approved': 'true',
        'status': 'DRAFT',
      };
      final editor = ManagementEditor(ManagementArea.fertilizers, null, {});
      final body = managementWrite(editor, fields);
      expect((body['product'] as Map)['sourceReference'], fields['source.url']);
      expect((body['information'] as Map)['applicationRateText'], isNull);
      expect(body.containsKey('rule'), false);
      expect(
        () => managementWrite(editor, {...fields, 'approved': 'false'}),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'model-review intake serializes units and source while requesting no execution or invented coefficients',
    () {
      final body = managementWrite(
        ManagementEditor(ManagementArea.modelSpecifications, null, {}),
        {
          'modelKey': 'synthetic-model',
          'kind': 'YIELD',
          'title': 'Synthetic specification',
          'mathematicalDefinition':
              'Synthetic contract only, not an approved field model.',
          'applicability': 'Isolated tests',
          'assumptions': 'No agronomic validity',
          'inputs': jsonEncode([
            {'key': 'area', 'unit': 'HECTARE', 'description': 'Synthetic area'},
          ]),
          'outputs': jsonEncode([
            for (final key in ['minimum', 'expected', 'potential'])
              {'key': key, 'unit': 'KG', 'description': 'Synthetic output'},
          ]),
          'coefficients': '[]',
          'source.title': 'Synthetic source',
          'source.publisher': 'Test generator',
          'source.url': 'https://example.invalid/model',
          'source.citation': 'Synthetic source reference',
          'reviewNote': 'Review source intake without enabling calculations.',
          'approved': 'true',
        },
      );
      expect(body['expectedVersion'], 0);
      expect(body['coefficients'], isEmpty);
      expect(body.containsKey('execution'), false);
    },
  );
  test(
    'operational schema rejects invented counters and distinguishes unavailable from empty collection',
    () {
      expect(AiOperations.fromJson({'status': 'UNAVAILABLE'}).dropped, isNull);
      final raw = {
        'status': 'COLLECTED',
        'totals': <Object>[],
        'daily': <Object>[],
        'collection': {'localDropped': 0},
      };
      expect(AiOperations.fromJson(raw).rows, isEmpty);
      expect(
        () => AiOperations.fromJson({
          ...raw,
          'totals': [
            {
              'scope': 'NODE',
              'operation': 'GENERATION',
              'requests': 1,
              'successes': 2,
              'failures': 0,
              'abstained': 0,
              'averageMs': 10,
              'p50Ms': 10,
              'p95Ms': 10,
            },
          ],
        }),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'reference model rejects Cloudinary URL leakage and missing license/source',
    () {
      expect(ReferenceMedia.fromJson(mediaJson()).synthetic, true);
      for (final change in [
        {'imagePath': 'https://res.cloudinary.com/private.png'},
        {'provenance': {}},
        {'sortOrder': -1},
      ]) {
        expect(
          () => ReferenceMedia.fromJson({...mediaJson(), ...change}),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
  test(
    'optional sourced applicability distinguishes informational entries without inventing Healthy treatment',
    () {
      final detail = DiseaseDetail.fromJson({
        ...detailJson(),
        'sections': <Object>[],
        'catalogue': {
          'classifierSupported': false,
          'literalLabel': null,
          'applicability': {
            'growthStages': ['Synthetic stage'],
            'severityDescriptors': <String>[],
            'source': sourceJson(),
          },
        },
      });
      expect(detail.classifierSupported, false);
      expect(detail.sections, isEmpty);
      expect(detail.metadataSource, isNotNull);
    },
  );
  test(
    'gallery ViewModel handles repository failure, retry, empty content and disposal',
    () async {
      var failing = true;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/diseases/healthy/images');
          if (failing) throw const AppException(AppErrorKind.network);
          return response({
            'items': [mediaJson()],
          });
        }),
      );
      addTearDown(api.close);
      final vm = ReferenceGalleryViewModel(
        ReferenceMediaRepository(api),
        'healthy',
      );
      await vm.load();
      expect(vm.error, isNotNull);
      failing = false;
      await vm.load();
      expect(vm.items.single.synthetic, true);
      expect(vm.error, isNull);
      vm.dispose();
      expect(vm.items, isEmpty);
      await vm.load();
    },
  );
  testWidgets(
    'operational widgets show unavailable, empty and genuine scoped metrics',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiOperationsPanel(
              data: AiOperations('UNAVAILABLE', [], [], null),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('unknown counts are not zero'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiOperationsPanel(data: AiOperations('COLLECTED', [], [], 0)),
          ),
        ),
      );
      expect(find.textContaining('No recorded operations'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiOperationsPanel(
              data: AiOperations(
                'COLLECTED',
                [
                  AiOperationSummary(
                    'NODE',
                    'INFERENCE',
                    2,
                    1,
                    1,
                    0,
                    10,
                    10,
                    20,
                  ),
                ],
                [],
                0,
              ),
            ),
          ),
        ),
      );
      expect(find.text('NODE · INFERENCE'), findsOneWidget);
      expect(find.text('Failure rate: 50.0%'), findsOneWidget);
    },
  );
}
