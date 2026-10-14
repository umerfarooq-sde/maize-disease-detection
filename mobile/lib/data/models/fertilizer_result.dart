import '../../core/exceptions/app_exception.dart';
import 'fertilizer_contract.dart';
import 'fertilizer_input.dart';
import 'fertilizer_rule.dart';

class FertilizerResult {
  FertilizerResult._({
    required this.input,
    required this.normalizedArea,
    required this.quantity,
    required this.rounding,
    required this.rule,
    required this.engineVersion,
    required this.explanation,
    required List<String> assumptions,
    required this.unitReference,
  }) : assumptions = List.unmodifiable(assumptions);

  final FertilizerInput input;
  final FertilizerNormalizedArea normalizedArea;
  final FertilizerQuantity quantity;
  final FertilizerRounding rounding;
  final FertilizerRule rule;
  final String engineVersion;
  final String explanation;
  final List<String> assumptions;
  final FertilizerUnitReference unitReference;

  factory FertilizerResult.fromJson(Object? value) {
    final data = fertilizerObject(value, const {
      'input',
      'normalizedArea',
      'quantity',
      'rounding',
      'rule',
      'engineVersion',
      'explanation',
      'assumptions',
      'unitReference',
    });
    final rawInput = fertilizerObject(data['input'], const {
      'area',
      'areaUnit',
      'outputUnit',
      'ruleId',
      'ruleVersion',
      'configVersion',
    });
    final input = _readInput(rawInput);
    final rule = FertilizerRule.fromJson(data['rule']);
    final quantity = FertilizerQuantity._fromJson(data['quantity']);
    final rounding = FertilizerRounding._fromJson(data['rounding']);
    if (data['engineVersion'] != 'area-rate-v1' ||
        rule.id != input.ruleId ||
        rule.version != input.ruleVersion ||
        rule.config.version != input.configVersion ||
        quantity.unit != input.outputUnit ||
        rounding.decimalPlaces != rule.config.quantityDecimalPlaces ||
        !_fixedPrecision(quantity.value, rounding.decimalPlaces)) {
      throw invalidFertilizerResponse();
    }
    return FertilizerResult._(
      input: input,
      normalizedArea: FertilizerNormalizedArea._fromJson(
        data['normalizedArea'],
      ),
      quantity: quantity,
      rounding: rounding,
      rule: rule,
      engineVersion: data['engineVersion'] as String,
      explanation: fertilizerText(data['explanation'], 4000),
      assumptions: fertilizerList(
        data['assumptions'],
        20,
      ).map((value) => fertilizerText(value, 2000)).toList(),
      unitReference: FertilizerUnitReference._fromJson(data['unitReference']),
    );
  }

  bool matches(FertilizerInput request) =>
      input.area == request.area &&
      input.areaUnit == request.areaUnit &&
      input.outputUnit == request.outputUnit &&
      input.ruleId == request.ruleId &&
      input.ruleVersion == request.ruleVersion &&
      input.configVersion == request.configVersion;

  static FertilizerInput _readInput(Map<String, dynamic> input) {
    try {
      return FertilizerInput(
        area: fertilizerText(input['area'], 24),
        areaUnit: switch (input['areaUnit']) {
          'HECTARE' => FertilizerAreaUnit.hectare,
          'ACRE' => FertilizerAreaUnit.acre,
          _ => throw invalidFertilizerResponse(),
        },
        outputUnit: _massUnit(input['outputUnit']),
        ruleId: fertilizerText(input['ruleId'], 36),
        ruleVersion: fertilizerInteger(input['ruleVersion']),
        configVersion: fertilizerInteger(input['configVersion']),
      );
    } on AppException {
      throw invalidFertilizerResponse();
    }
  }

  static bool _fixedPrecision(String value, int places) {
    final parts = value.split('.');
    return places == 0
        ? parts.length == 1
        : parts.length == 2 && parts.last.length == places;
  }
}

class FertilizerNormalizedArea {
  const FertilizerNormalizedArea._(this.value, this.unit);
  final String value;
  final FertilizerAreaUnit unit;
  factory FertilizerNormalizedArea._fromJson(Object? value) {
    final data = fertilizerObject(value, const {'value', 'unit'});
    if (data['unit'] != 'HECTARE') throw invalidFertilizerResponse();
    final area = fertilizerDecimal(data['value']);
    if (BigInt.parse(area.replaceAll('.', '')) == BigInt.zero) {
      throw invalidFertilizerResponse();
    }
    return FertilizerNormalizedArea._(area, FertilizerAreaUnit.hectare);
  }
}

class FertilizerQuantity {
  const FertilizerQuantity._(this.value, this.unit, this.unroundedValue);
  final String value;
  final FertilizerMassUnit unit;
  final String unroundedValue;
  factory FertilizerQuantity._fromJson(Object? value) {
    final data = fertilizerObject(value, const {
      'value',
      'unit',
      'unroundedValue',
    });
    return FertilizerQuantity._(
      fertilizerDecimal(data['value'], maximumDecimalPlaces: 6),
      _massUnit(data['unit']),
      fertilizerDecimal(data['unroundedValue']),
    );
  }
}

class FertilizerRounding {
  const FertilizerRounding._(this.mode, this.decimalPlaces);
  final String mode;
  final int decimalPlaces;
  factory FertilizerRounding._fromJson(Object? value) {
    final data = fertilizerObject(value, const {'mode', 'decimalPlaces'});
    if (data['mode'] != 'HALF_UP') throw invalidFertilizerResponse();
    return FertilizerRounding._(
      data['mode'] as String,
      fertilizerInteger(data['decimalPlaces'], minimum: 0, maximum: 6),
    );
  }
}

class FertilizerUnitReference {
  const FertilizerUnitReference._(this.title, this.url);
  final String title;
  final Uri url;
  factory FertilizerUnitReference._fromJson(Object? value) {
    final data = fertilizerObject(value, const {'title', 'url'});
    return FertilizerUnitReference._(
      fertilizerText(data['title'], 255),
      fertilizerHttpsUrl(data['url']),
    );
  }
}

FertilizerMassUnit _massUnit(Object? value) => switch (value) {
  'KG' => FertilizerMassUnit.kg,
  'G' => FertilizerMassUnit.grams,
  _ => throw invalidFertilizerResponse(),
};
