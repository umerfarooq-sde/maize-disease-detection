import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/data/datasources/fertilizer_datasource.dart';
import 'package:maizedoctor/data/models/fertilizer_models.dart';
import 'package:maizedoctor/data/repositories/fertilizer_repository.dart';
import 'helpers.dart';

http.Response response(Object? data, {int status = 200}) => http.Response(
  jsonEncode({
    'success': status == 200,
    'data': data,
    if (status != 200)
      'error': {'code': 'INTERNAL_DETAIL', 'message': 'private rule data'},
    'requestId': '00000000-0000-4000-8000-000000000001',
  }),
  status,
  headers: {'content-type': 'application/json'},
);

Matcher failure(AppErrorKind kind) =>
    throwsA(isA<AppException>().having((error) => error.kind, 'kind', kind));

class _Tokens implements AccessTokenSource {
  @override
  Future<String?> readAccessToken() async => 'header.payload.signature';
}

void main() {
  final config = AppConfig(apiBaseUrl: 'https://api.example.test/api/v1');

  test(
    'public catalogue uses Node only and sends no credentials or personal data',
    () async {
      http.Request? sent;
      final api = ApiClient(
        config: config,
        tokenSource: _Tokens(),
        client: MockClient((request) async {
          sent = request;
          return response(catalogueJson(pending: true));
        }),
      );
      addTearDown(api.close);
      final repository = ApiFertilizerRepository(FertilizerDatasource(api));
      final result = await repository.rules();
      expect(sent!.method, 'GET');
      expect(
        sent!.url.toString(),
        'https://api.example.test/api/v1/calculators/fertilizer/rules',
      );
      expect(sent!.headers.containsKey('Authorization'), false);
      expect(sent!.body, isEmpty);
      expect(result.status, FertilizerCatalogueStatus.pendingRules);
    },
  );

  test(
    'only explicit area/unit and version-pinned rule inputs are submitted',
    () async {
      http.Request? sent;
      final input = fixtureInput(
        area: '1.500000',
        areaUnit: FertilizerAreaUnit.acre,
      );
      final api = ApiClient(
        config: config,
        client: MockClient((request) async {
          sent = request;
          return response(
            resultJson(
              input: input,
              normalizedArea: '0.60702846336',
              quantity: '7.588',
              unrounded: '7.587855792',
            ),
          );
        }),
      );
      addTearDown(api.close);
      final result = await ApiFertilizerRepository(
        FertilizerDatasource(api),
      ).calculate(input);
      expect(sent!.method, 'POST');
      expect(sent!.url.path, '/api/v1/calculators/fertilizer/calculate');
      expect(sent!.headers['X-Auth-Request'], '1');
      expect(jsonDecode(sent!.body), input.toJson());
      expect(sent!.body, isNot(contains('rateKgPerHectare')));
      expect(sent!.body, isNot(contains('Gemini')));
      expect(result.quantity.value, '7.588');
      expect(result.normalizedArea.value, '0.60702846336');
    },
  );

  test(
    'server-calculated grams and raw decimal precision are never recomputed',
    () async {
      final input = fixtureInput(outputUnit: FertilizerMassUnit.grams);
      final api = ApiClient(
        config: config,
        client: MockClient(
          (_) async => response(
            resultJson(input: input, quantity: '25000.000', unrounded: '25000'),
          ),
        ),
      );
      addTearDown(api.close);
      final result = await ApiFertilizerRepository(
        FertilizerDatasource(api),
      ).calculate(input);
      expect(result.quantity.value, '25000.000');
      expect(result.quantity.unit, FertilizerMassUnit.grams);
      expect(result.quantity.unroundedValue, '25000');
    },
  );

  test(
    'malformed or incompatible responses never yield a fake recommendation',
    () async {
      Object? data = {'status': 'READY', 'items': []};
      final api = ApiClient(
        config: config,
        client: MockClient((_) async => response(data)),
      );
      addTearDown(api.close);
      final repository = ApiFertilizerRepository(FertilizerDatasource(api));
      await expectLater(
        repository.rules(),
        failure(AppErrorKind.invalidResponse),
      );
      data = {
        ...resultJson(),
        'quantity': {'value': '25.000', 'unit': 'LB', 'unroundedValue': '25'},
      };
      await expectLater(
        repository.calculate(fixtureInput()),
        failure(AppErrorKind.invalidResponse),
      );
      data = resultJson(input: fixtureInput(area: '3'));
      await expectLater(
        repository.calculate(fixtureInput()),
        failure(AppErrorKind.invalidResponse),
      );
    },
  );

  test(
    'stale versions, unavailable service and invalid input have safe errors',
    () async {
      var status = 409;
      final api = ApiClient(
        config: config,
        client: MockClient((_) async => response(null, status: status)),
      );
      addTearDown(api.close);
      final repository = ApiFertilizerRepository(FertilizerDatasource(api));
      for (final entry in <int, AppErrorKind>{
        409: AppErrorKind.conflict,
        404: AppErrorKind.notFound,
        400: AppErrorKind.validation,
        429: AppErrorKind.rateLimited,
        503: AppErrorKind.server,
      }.entries) {
        status = entry.key;
        await expectLater(
          repository.calculate(fixtureInput()),
          failure(entry.value),
        );
        expect(
          AppException(entry.value).message,
          isNot(contains('private rule data')),
        );
      }
    },
  );

  test(
    'network failure does not calculate locally or retry without intent',
    () async {
      var calls = 0;
      final api = ApiClient(
        config: config,
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('private backend host');
        }),
      );
      addTearDown(api.close);
      await expectLater(
        ApiFertilizerRepository(
          FertilizerDatasource(api),
        ).calculate(fixtureInput()),
        failure(AppErrorKind.network),
      );
      expect(calls, 1);
    },
  );
}
