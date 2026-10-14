import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/fertilizer_input.dart';

void main() {
  test(
    'positive decimal text is preserved without floating-point conversion',
    () {
      for (final value in [
        '0.000001',
        '1',
        '1.125',
        '12.500000',
        '100',
        '1000000.000000',
      ]) {
        expect(normalizeFertilizerArea('  $value  '), value);
      }
    },
  );

  test(
    'missing, negative, impossible and ambiguous area notation is rejected',
    () {
      for (final value in [
        '',
        ' ',
        '0',
        '0.000000',
        '-1',
        '+1',
        '01',
        '.1',
        '1.',
        '1.0000001',
        '1000000.000001',
        '1000001',
        '1,5',
        '1,000',
        '1e2',
        'NaN',
        'Infinity',
        '١',
        '1\n2',
        '1\u0000',
        '9' * 25,
      ]) {
        expect(
          () => normalizeFertilizerArea(value),
          throwsA(isA<AppException>()),
          reason: 'Reject ambiguous area: $value',
        );
      }
    },
  );

  test('request pins rule/config versions and explicit area/mass units', () {
    final input = FertilizerInput(
      area: ' 1.500000 ',
      areaUnit: FertilizerAreaUnit.acre,
      ruleId: '00000000-0000-4000-8000-000000000001',
      ruleVersion: 2,
      configVersion: 3,
      outputUnit: FertilizerMassUnit.grams,
    );
    expect(input.toJson(), {
      'area': '1.500000',
      'areaUnit': 'ACRE',
      'ruleId': '00000000-0000-4000-8000-000000000001',
      'ruleVersion': 2,
      'configVersion': 3,
      'outputUnit': 'G',
    });
  });

  test('rule identifiers and versions fail before a network call', () {
    for (final change in [
      (id: 'untrusted/path', rule: 1, config: 1),
      (id: '00000000-0000-4000-8000-000000000001', rule: 0, config: 1),
      (id: '00000000-0000-4000-8000-000000000001', rule: 1, config: 0),
      (id: '00000000-0000-4000-8000-000000000001', rule: 1, config: 2147483648),
    ]) {
      expect(
        () => FertilizerInput(
          area: '1',
          areaUnit: FertilizerAreaUnit.hectare,
          ruleId: change.id,
          ruleVersion: change.rule,
          configVersion: change.config,
          outputUnit: FertilizerMassUnit.kg,
        ),
        throwsA(isA<AppException>()),
      );
    }
  });
}
