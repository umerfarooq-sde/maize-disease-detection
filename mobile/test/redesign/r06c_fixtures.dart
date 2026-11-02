import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import '../auth/session_test.dart' show response;
import 'r06b_fixtures.dart';

const r06cSource = {
  'title': 'Synthetic source',
  'publisher': 'UI fixture generator',
  'url': 'https://example.invalid/calculator',
  'citation':
      'Synthetic contract fixture only; no agricultural recommendation.',
};
Map<String, dynamic> r06cProduct() => {
  'slug': 'synthetic-product',
  'name': 'Synthetic product · not a recommendation',
  'description': 'Synthetic product for isolated frontend tests.',
  'nitrogenPercent': '12.50',
  'phosphorusPercent': '0',
  'potassiumPercent': '0',
  'sourceReference': 'https://example.invalid/calculator',
  'applicationMethod': null,
  'precautions': <String>[],
};
Map<String, dynamic> r06cVariable(String key) => {
  'key': key,
  'unit': 'KG',
  'description': 'Synthetic definition only',
};
Map<String, dynamic> r06cSpec() => {
  'modelKey': 'synthetic-model',
  'kind': 'YIELD',
  'title': 'Synthetic model intake',
  'mathematicalDefinition':
      'Synthetic mathematical description. Never executable.',
  'applicability': 'Isolated tests only',
  'assumptions': ['No agronomic approval'],
  'inputs': [r06cVariable('area')],
  'outputs': [
    for (final key in ['minimum', 'expected', 'potential']) r06cVariable(key),
  ],
  'coefficients': [
    {
      'key': 'example',
      'unit': 'DIMENSIONLESS',
      'value': '-0.000000000000000000123400',
      'sourceSection': 'Synthetic precision fixture',
    },
  ],
  'source': r06cSource,
};
Map<String, dynamic> r06cRecord(ManagementArea area) {
  final base = <String, dynamic>{
    'id': '00000000-0000-4000-8000-000000000001',
    'version': 1,
    'status': 'DRAFT',
    'validForActivation': true,
  };
  final rule = {
    'version': 1,
    'title': 'Synthetic reviewed rule',
    'rateKgPerHectare': '123.125',
    'applicability': 'Isolated UI testing only',
    'assumptions': ['Synthetic, never a recommendation'],
    'source': r06cSource,
  };
  return switch (area) {
    ManagementArea.fertilizers => {
      ...base,
      'title': 'Synthetic product',
      'revision': 'a' * 64,
      'contentEditable': true,
      'rulesCount': 0,
      'draftInput': {
        'product': r06cProduct(),
        'information': {
          'source': r06cSource,
          'type': null,
          'growthStages': <String>[],
          'suitableConditions': <String>[],
          'applicationRateText': null,
        },
      },
    },
    ManagementArea.fertilizer => {
      ...base,
      'title': 'Synthetic product-rate rule',
      'ruleKey': 'synthetic-rule',
      'configVersion': 1,
      'product': {
        'name': 'Synthetic product',
        'slug': 'synthetic-product',
        'status': 'ACTIVE',
      },
      'draftInput': {
        'product': r06cProduct(),
        'rule': {...rule, 'ruleKey': 'synthetic-rule'},
        'config': {'version': 1, 'quantityDecimalPlaces': 3},
      },
    },
    ManagementArea.yieldRules => {
      ...base,
      'title': 'Synthetic reference yield',
      'configKey': 'maize-yield',
      'draftInput': {
        ...rule,
        'expectedYieldKgPerHectare': '456.125',
        'quantityDecimalPlaces': 3,
      },
    },
    _ => {
      ...base,
      'title': 'Synthetic model intake',
      'validForActivation': false,
      'execution': 'DISABLED',
      'domainApproval': 'PENDING_DOMAIN_APPROVAL',
      'draftInput': r06cSpec(),
    },
  };
}

class R06CFixture extends R06BFixture {
  bool emptyCalculators = false;
  final records = {
    for (final area in [
      ManagementArea.fertilizers,
      ManagementArea.fertilizer,
      ManagementArea.yieldRules,
      ManagementArea.modelSpecifications,
    ])
      area: r06cRecord(area),
  };
  @override
  http.Client client() {
    final fallback = super.client();
    return MockClient((request) async {
      final path = request.url.path;
      final area = path.contains('/admin/fertilizers')
          ? ManagementArea.fertilizers
          : path.contains('/admin/calculators/fertilizer')
          ? ManagementArea.fertilizer
          : path.contains('/admin/calculators/yield')
          ? ManagementArea.yieldRules
          : path.contains('/admin/calculators/model-specifications')
          ? ManagementArea.modelSpecifications
          : null;
      if (area == null) {
        final copy = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        return fallback.send(copy).then(http.Response.fromStream);
      }
      requests.add(request);
      expect(request.headers['authorization'], 'Bearer admin.access.token');
      if (request.method == 'GET') {
        return response(
          listStatus == 200
              ? {
                  'items': emptyCalculators ? [] : [records[area]],
                  'nextCursor': null,
                }
              : null,
          status: listStatus,
        );
      }
      writes.add(request);
      await mutationGate?.future;
      if (mutationStatus != 200) return response(null, status: mutationStatus);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (path.endsWith('/status')) {
        records[area]!['status'] = body['status'];
      } else {
        final draft = area == ManagementArea.fertilizers
            ? {'product': body['product'], 'information': body['information']}
            : body;
        records[area] = {
          ...records[area]!,
          'draftInput': draft,
          'status': area == ManagementArea.fertilizers
              ? body['status']
              : 'DRAFT',
          'version': area == ManagementArea.modelSpecifications
              ? (body['expectedVersion'] as int) + 1
              : area == ManagementArea.fertilizer
              ? (body['rule'] as Map)['version']
              : body['version'] ?? 2,
        };
      }
      return response(null);
    });
  }
}
