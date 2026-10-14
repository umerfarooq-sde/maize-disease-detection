import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/fertilizer_models.dart';
import 'helpers.dart';

Matcher get invalid => throwsA(
  isA<AppException>().having(
    (failure) => failure.kind,
    'kind',
    AppErrorKind.invalidResponse,
  ),
);

void main() {
  test('pending catalogue has no guessed rate, product or configuration', () {
    final pending = catalogue(pending: true);
    expect(pending.status, FertilizerCatalogueStatus.pendingRules);
    expect(pending.items, isEmpty);
    expect(pending.message, contains('pending'));
    expect(() => pending.items.clear(), throwsUnsupportedError);
  });

  test('reviewed rule metadata and decimal strings are immutable', () {
    final rule = catalogue().items.single;
    expect(rule.crop, 'MAIZE');
    expect(rule.rateKgPerHectare, '12.5');
    expect(rule.source.url.scheme, 'https');
    expect(rule.config.key, 'maize-area-rate');
    expect(rule.config.roundingMode, 'HALF_UP');
    expect(rule.config.quantityDecimalPlaces, 3);
    expect(() => rule.assumptions.clear(), throwsUnsupportedError);
  });

  test(
    'catalogue status, duplicates and engine incompatibility fail closed',
    () {
      for (final data in [
        {...catalogueJson(), 'status': 'UNKNOWN'},
        {...catalogueJson(), 'items': <Object?>[]},
        {...catalogueJson(), 'status': 'PENDING_RULES'},
        {
          ...catalogueJson(),
          'items': [ruleJson(), ruleJson()],
        },
        {...catalogueJson(), 'engineVersion': 'guessed-v2'},
        {...catalogueJson(), 'fallbackRate': '10'},
      ]) {
        expect(() => FertilizerCatalogue.fromJson(data), invalid);
      }
    },
  );

  test(
    'unsupported crops, impossible rates and absent assumptions are rejected',
    () {
      for (final change in <String, Object?>{
        'crop': 'WHEAT',
        'rateKgPerHectare': -1,
        'version': 0,
        'id': 'unsafe/path',
        'assumptions': <Object?>[],
        'applicability': 'bad\u0000metadata',
      }.entries) {
        expect(
          () => FertilizerRule.fromJson({
            ...ruleJson(),
            change.key: change.value,
          }),
          invalid,
        );
      }
      for (final rate in ['-1', '1e3', 'NaN', '1000000.000001', '1.1234567']) {
        expect(() => FertilizerRule.fromJson(ruleJson(rate: rate)), invalid);
      }
      expect(
        FertilizerRule.fromJson(ruleJson(rate: '0')).rateKgPerHectare,
        '0',
      );
    },
  );

  test('untrusted source references never become actionable source URLs', () {
    for (final url in [
      'http://example.test/source',
      'javascript:alert(1)',
      'https://secret@example.test/source',
      'https://example.test/source\nprivate',
      'https://example.test/source with spaces',
    ]) {
      final data = ruleJson();
      final source = data['source']! as Map<String, Object?>;
      data['source'] = {...source, 'url': url};
      expect(() => FertilizerRule.fromJson(data), invalid);
    }
  });

  test('configuration versions and rounding are explicit and bounded', () {
    final original = ruleJson();
    final config = original['config']! as Map<String, Object?>;
    for (final change in <String, Object?>{
      'key': 'unknown-calculator',
      'version': 0,
      'engineVersion': 'area-rate-v2',
      'quantityDecimalPlaces': 7,
      'roundingMode': 'BANKERS',
    }.entries) {
      expect(
        () => FertilizerRule.fromJson({
          ...original,
          'config': {...config, change.key: change.value},
        }),
        invalid,
      );
    }
  });

  test(
    'quantities are retained exactly including trailing zeros and raw amount',
    () {
      final result = fertilizerResult();
      expect(result.quantity.value, '25.000');
      expect(result.quantity.unroundedValue, '25');
      expect(result.quantity.unit, FertilizerMassUnit.kg);
      expect(result.normalizedArea.value, '2');
      expect(result.normalizedArea.unit, FertilizerAreaUnit.hectare);
      expect(result.input.area, '2');
      expect(() => result.assumptions.clear(), throwsUnsupportedError);
    },
  );

  test(
    'valid rounded zero is preserved rather than replacing it with a fake minimum',
    () {
      final result = FertilizerResult.fromJson(
        resultJson(
          input: fixtureInput(area: '0.000001'),
          quantity: '0.000',
          unrounded: '0.0000125',
          normalizedArea: '0.000001',
        ),
      );
      expect(result.quantity.value, '0.000');
      expect(result.quantity.unroundedValue, '0.0000125');
    },
  );

  test('result requires coherent input, rule and config versions', () {
    for (final rule in [
      ruleJson(version: 2),
      ruleJson(configVersion: 2),
      ruleJson(id: '00000000-0000-4000-8000-000000000002'),
    ]) {
      expect(() => FertilizerResult.fromJson(resultJson(rule: rule)), invalid);
    }
    final data = resultJson();
    final input = data['input']! as Map<String, Object?>;
    expect(
      () => FertilizerResult.fromJson({
        ...data,
        'input': {...input, 'area': '0'},
      }),
      invalid,
    );
  });

  test('mass/area unit and decimal precision mismatches are rejected', () {
    final data = resultJson();
    for (final quantity in [
      {'value': '25.000', 'unroundedValue': '25', 'unit': 'TONNES'},
      {'value': '25.000', 'unroundedValue': '25', 'unit': 'G'},
      {'value': '25', 'unroundedValue': '25', 'unit': 'KG'},
      {'value': '-25.000', 'unroundedValue': '25', 'unit': 'KG'},
      {'value': '25.000', 'unroundedValue': '25e0', 'unit': 'KG'},
      {'value': 25, 'unroundedValue': '25', 'unit': 'KG'},
    ]) {
      expect(
        () => FertilizerResult.fromJson({...data, 'quantity': quantity}),
        invalid,
      );
    }
    for (final normalized in [
      {'value': '2', 'unit': 'ACRE'},
      {'value': '0', 'unit': 'HECTARE'},
    ]) {
      expect(
        () =>
            FertilizerResult.fromJson({...data, 'normalizedArea': normalized}),
        invalid,
      );
    }
    expect(
      () => FertilizerResult.fromJson({
        ...data,
        'rounding': {'mode': 'HALF_UP', 'decimalPlaces': 2},
      }),
      invalid,
    );
  });

  test(
    'explicit gram result and zero decimal place configuration are supported',
    () {
      final grams = fixtureInput(outputUnit: FertilizerMassUnit.grams);
      final result = FertilizerResult.fromJson(
        resultJson(
          input: grams,
          quantity: '25000',
          unrounded: '25000',
          decimalPlaces: 0,
        ),
      );
      expect(result.quantity.unit, FertilizerMassUnit.grams);
      expect(result.quantity.value, '25000');
      expect(result.rounding.decimalPlaces, 0);
      expect(result.matches(grams), true);
    },
  );

  test(
    'a response for different input cannot replace the submitted calculation',
    () {
      final result = fertilizerResult();
      for (final other in [
        fixtureInput(area: '3'),
        fixtureInput(areaUnit: FertilizerAreaUnit.acre),
        fixtureInput(outputUnit: FertilizerMassUnit.grams),
        fixtureInput(ruleVersion: 2),
        fixtureInput(configVersion: 2),
      ]) {
        expect(result.matches(other), false);
      }
    },
  );
}
