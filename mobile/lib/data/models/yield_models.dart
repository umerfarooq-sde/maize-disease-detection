import '../../core/exceptions/app_exception.dart';
import 'calculator_contract.dart';
import 'calculator_input.dart';
export 'calculator_input.dart' show CalculatorAreaUnit;

const yieldEngineVersion = 'area-yield-v1';
const yieldFormulaVersion = 'area-times-reviewed-yield-rate-v1';

enum YieldMassUnit {
  kg('KG', 'kg', 'Kilograms (kg)'),
  tonnes('TONNE', 't', 'Metric tonnes (t)');

  const YieldMassUnit(this.wireValue, this.label, this.description);
  final String wireValue;
  final String label;
  final String description;
}

YieldMassUnit _massUnit(Object? value) => switch (value) {
  'KG' => YieldMassUnit.kg,
  'TONNE' => YieldMassUnit.tonnes,
  _ => throw invalidCalculatorResponse(),
};
String _uuid(Object? value) => calculatorPattern(
  value,
  36,
  r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
);

class YieldInput {
  YieldInput({
    required String area,
    required this.areaUnit,
    required this.outputUnit,
    required this.configId,
    required this.configVersion,
  }) : area = normalizeCalculatorArea(area) {
    try {
      _uuid(configId);
      calculatorInteger(configVersion);
    } on AppException {
      throw const AppException(AppErrorKind.validation);
    }
  }
  final String area;
  final CalculatorAreaUnit areaUnit;
  final YieldMassUnit outputUnit;
  final String configId;
  final int configVersion;
  Map<String, Object?> toJson() => {
    'area': area,
    'areaUnit': areaUnit.wireValue,
    'outputUnit': outputUnit.wireValue,
    'configId': configId,
    'configVersion': configVersion,
  };
  factory YieldInput.fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'area',
      'areaUnit',
      'outputUnit',
      'configId',
      'configVersion',
    });
    try {
      return YieldInput(
        area: calculatorText(data['area'], 14),
        areaUnit: switch (data['areaUnit']) {
          'HECTARE' => CalculatorAreaUnit.hectare,
          'ACRE' => CalculatorAreaUnit.acre,
          _ => throw invalidCalculatorResponse(),
        },
        outputUnit: _massUnit(data['outputUnit']),
        configId: _uuid(data['configId']),
        configVersion: calculatorInteger(data['configVersion']),
      );
    } on AppException {
      throw invalidCalculatorResponse();
    }
  }
  bool matches(YieldInput other) =>
      area == other.area &&
      areaUnit == other.areaUnit &&
      outputUnit == other.outputUnit &&
      configId == other.configId &&
      configVersion == other.configVersion;
}

class YieldConfiguration {
  YieldConfiguration._({
    required this.id,
    required this.configKey,
    required this.version,
    required this.title,
    required this.expectedYieldKgPerHectare,
    required this.applicability,
    required List<String> assumptions,
    required this.source,
    required this.decimalPlaces,
  }) : assumptions = List.unmodifiable(assumptions);
  final String id;
  final String configKey;
  final int version;
  final String title;
  final String expectedYieldKgPerHectare;
  final String applicability;
  final List<String> assumptions;
  final CalculatorSource source;
  final int decimalPlaces;
  factory YieldConfiguration.fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'id',
      'configKey',
      'version',
      'title',
      'crop',
      'expectedYieldKgPerHectare',
      'applicability',
      'assumptions',
      'source',
      'engineVersion',
      'formulaVersion',
      'rounding',
    });
    final rounding = calculatorObject(data['rounding'], const {
      'mode',
      'decimalPlaces',
    });
    if (data['configKey'] != 'maize-area-yield' ||
        data['crop'] != 'MAIZE' ||
        data['engineVersion'] != yieldEngineVersion ||
        data['formulaVersion'] != yieldFormulaVersion ||
        rounding['mode'] != 'HALF_UP') {
      throw invalidCalculatorResponse();
    }
    final rate = calculatorDecimal(
      data['expectedYieldKgPerHectare'],
      maximumDecimalPlaces: 6,
    );
    try {
      normalizeCalculatorDecimal(rate, allowZero: true);
    } on AppException {
      throw invalidCalculatorResponse();
    }
    final assumptions = calculatorList(data['assumptions'], 8);
    if (assumptions.isEmpty) throw invalidCalculatorResponse();
    return YieldConfiguration._(
      id: _uuid(data['id']),
      configKey: data['configKey'] as String,
      version: calculatorInteger(data['version']),
      title: calculatorText(data['title'], 160),
      expectedYieldKgPerHectare: rate,
      applicability: calculatorText(data['applicability'], 2000),
      assumptions: assumptions
          .map((value) => calculatorText(value, 400))
          .toList(),
      source: CalculatorSource.fromJson(data['source']),
      decimalPlaces: calculatorInteger(
        rounding['decimalPlaces'],
        minimum: 0,
        maximum: 6,
      ),
    );
  }
}

enum YieldCatalogueStatus { ready, pendingConfiguration }

class YieldCatalogue {
  YieldCatalogue._(this.status, this.message, List<YieldConfiguration> items)
    : items = List.unmodifiable(items);
  final YieldCatalogueStatus status;
  final String message;
  final List<YieldConfiguration> items;
  factory YieldCatalogue.fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'status',
      'message',
      'engineVersion',
      'items',
    });
    final status = switch (data['status']) {
      'READY' => YieldCatalogueStatus.ready,
      'PENDING_CONFIGURATION' => YieldCatalogueStatus.pendingConfiguration,
      _ => throw invalidCalculatorResponse(),
    };
    final items = calculatorList(
      data['items'],
      100,
    ).map(YieldConfiguration.fromJson).toList();
    if (data['engineVersion'] != yieldEngineVersion ||
        (status == YieldCatalogueStatus.ready
            ? items.isEmpty
            : items.isNotEmpty) ||
        items.map((item) => item.id).toSet().length != items.length) {
      throw invalidCalculatorResponse();
    }
    return YieldCatalogue._(
      status,
      calculatorText(data['message'], 2000),
      items,
    );
  }
}

class YieldResult {
  YieldResult._({
    required this.input,
    required this.configuration,
    required this.normalizedArea,
    required this.value,
    required this.unroundedValue,
    required this.explanation,
    required List<String> assumptions,
    required this.unitReferenceTitle,
    required this.unitReferenceUrl,
  }) : assumptions = List.unmodifiable(assumptions);
  final YieldInput input;
  final YieldConfiguration configuration;
  final String normalizedArea;
  final String value;
  final String unroundedValue;
  final String explanation;
  final List<String> assumptions;
  final String unitReferenceTitle;
  final Uri unitReferenceUrl;
  bool matches(YieldInput request) => input.matches(request);
  factory YieldResult.fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'input',
      'normalizedArea',
      'expectedYield',
      'configuration',
      'rounding',
      'engineVersion',
      'formulaVersion',
      'explanation',
      'assumptions',
      'unitReference',
    });
    final input = YieldInput.fromJson(data['input']);
    final configuration = YieldConfiguration.fromJson(data['configuration']);
    final area = calculatorObject(data['normalizedArea'], const {
      'value',
      'unit',
    });
    final quantity = calculatorObject(data['expectedYield'], const {
      'value',
      'unit',
      'unroundedValue',
    });
    final rounding = calculatorObject(data['rounding'], const {
      'mode',
      'decimalPlaces',
    });
    final reference = calculatorObject(data['unitReference'], const {
      'title',
      'url',
    });
    final amount = calculatorDecimal(
      quantity['value'],
      maximumDecimalPlaces: 6,
    );
    final parts = amount.split('.');
    final places = configuration.decimalPlaces;
    final normalizedArea = calculatorDecimal(area['value']);
    if (data['engineVersion'] != yieldEngineVersion ||
        data['formulaVersion'] != yieldFormulaVersion ||
        input.configId != configuration.id ||
        input.configVersion != configuration.version ||
        area['unit'] != 'HECTARE' ||
        BigInt.parse(normalizedArea.replaceAll('.', '')) == BigInt.zero ||
        quantity['unit'] != input.outputUnit.wireValue ||
        rounding['mode'] != 'HALF_UP' ||
        rounding['decimalPlaces'] != places ||
        (places == 0
            ? parts.length != 1
            : parts.length != 2 || parts.last.length != places)) {
      throw invalidCalculatorResponse();
    }
    return YieldResult._(
      input: input,
      configuration: configuration,
      normalizedArea: normalizedArea,
      value: amount,
      unroundedValue: calculatorDecimal(quantity['unroundedValue']),
      explanation: calculatorText(data['explanation'], 4000),
      assumptions: calculatorList(
        data['assumptions'],
        20,
      ).map((value) => calculatorText(value, 2000)).toList(),
      unitReferenceTitle: calculatorText(reference['title'], 255),
      unitReferenceUrl: calculatorHttpsUrl(reference['url']),
    );
  }
}
