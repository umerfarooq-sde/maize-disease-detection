import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/models/yield_models.dart';
import 'package:maizedoctor/data/repositories/yield_repository.dart';
import 'helpers.dart';

Matcher failure(AppErrorKind kind) =>
    throwsA(isA<AppException>().having((error) => error.kind, 'kind', kind));
void main() {
  test(
    'input accepts bounded decimal strings and exact explicit units/version fields',
    () {
      final input = fixtureInput(
        area: ' 1.250000 ',
        outputUnit: YieldMassUnit.tonnes,
      );
      expect(input.area, '1.250000');
      expect(input.toJson()['outputUnit'], 'TONNE');
      expect(input.toJson().keys.toSet(), {
        'area',
        'areaUnit',
        'outputUnit',
        'configId',
        'configVersion',
      });
      expect(fixtureInput(area: '1000000').area, '1000000');
      expect(fixtureInput(area: '0.000001').area, '0.000001');
    },
  );
  for (final area in [
    '',
    '0',
    '-1',
    '01',
    '.5',
    '1.',
    'NaN',
    '1e3',
    '1,2',
    '1000000.000001',
    '0.0000001',
  ]) {
    test('input rejects ambiguous/nonpositive/out-of-range area $area', () {
      expect(() => fixtureInput(area: area), failure(AppErrorKind.validation));
    });
  }
  test(
    'catalogue and result preserve versioned source/assumptions and exact quantity strings',
    () {
      final catalogue = YieldCatalogue.fromJson(catalogueJson());
      expect(catalogue.items.single.source.url.host, 'example.invalid');
      expect(() => catalogue.items.clear(), throwsUnsupportedError);
      final result = YieldResult.fromJson(resultJson());
      expect(result.value, '25.000');
      expect(result.unroundedValue, '25');
      expect(result.configuration.version, 1);
      expect(result.matches(fixtureInput()), true);
      expect(() => result.assumptions.clear(), throwsUnsupportedError);
      expect(
        YieldCatalogue.fromJson(catalogueJson(pending: true)).status,
        YieldCatalogueStatus.pendingConfiguration,
      );
    },
  );
  test(
    'incompatible formula/version/source/rate and unreviewed response fields fail parsing',
    () {
      for (final change in [
        {'formulaVersion': 'unknown'},
        {'engineVersion': 'other'},
        {'crop': 'RICE'},
        {'expectedYieldKgPerHectare': '1000000.1'},
        {'expectedYieldKgPerHectare': '-1'},
        {
          'source': {
            'title': 'x',
            'publisher': 'x',
            'url': 'http://example.invalid/x',
            'citation': 'x',
          },
        },
        {'extra': 'unknown'},
      ]) {
        expect(
          () =>
              YieldConfiguration.fromJson({...configurationJson(), ...change}),
          failure(AppErrorKind.invalidResponse),
        );
      }
      for (final change in [
        {'formulaVersion': 'other'},
        {'configuration': configurationJson(version: 2)},
        {
          'expectedYield': {
            'value': '25.00',
            'unit': 'KG',
            'unroundedValue': '25',
          },
        },
        {
          'expectedYield': {
            'value': '25.000',
            'unit': 'G',
            'unroundedValue': '25',
          },
        },
      ]) {
        expect(
          () => YieldResult.fromJson({...resultJson(), ...change}),
          failure(AppErrorKind.invalidResponse),
        );
      }
      expect(
        () => YieldCatalogue.fromJson(catalogueJson(items: [])),
        failure(AppErrorKind.invalidResponse),
      );
    },
  );
  test(
    'repository calls public Node endpoints and only sends the five validated inputs',
    () async {
      final sent = <http.Request>[];
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((request) async {
          sent.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': request.method == 'GET' ? catalogueJson() : resultJson(),
              'requestId': fixtureId,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);
      final repository = ApiYieldRepository(api);
      await repository.configurations();
      final result = await repository.calculate(fixtureInput());
      expect(sent.first.url.path, '/api/v1/calculators/yield/configurations');
      expect(sent.last.url.path, '/api/v1/calculators/yield/calculate');
      expect(
        sent.every((request) => !request.headers.containsKey('authorization')),
        true,
      );
      expect(jsonDecode(sent.last.body), fixtureInput().toJson());
      expect(result.value, '25.000');
    },
  );
  test(
    'repository rejects mismatched echoed inputs and handles safe error responses',
    () async {
      for (final status in [200, 409, 503]) {
        final api = ApiClient(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(
                status == 200
                    ? {
                        'success': true,
                        'data': resultJson(input: fixtureInput(area: '3')),
                        'requestId': fixtureId,
                      }
                    : {
                        'success': false,
                        'error': {
                          'code': 'YIELD_CONFIGURATION_CHANGED',
                          'message': 'private',
                        },
                        'requestId': fixtureId,
                      },
              ),
              status,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          ApiYieldRepository(api).calculate(fixtureInput()),
          failure(
            status == 200
                ? AppErrorKind.invalidResponse
                : status == 409
                ? AppErrorKind.conflict
                : AppErrorKind.server,
          ),
        );
      }
    },
  );
}
