import 'package:maizedoctor/data/models/fertilizer_models.dart';
import 'package:maizedoctor/data/repositories/fertilizer_repository.dart';

// All rates/products/source text here are synthetic arithmetic test fixtures.
// They are not agronomic advice and are never seeded into the application.
const fixtureRuleId = '00000000-0000-4000-8000-000000000001';

Map<String, Object?> ruleJson({
  String id = fixtureRuleId,
  int version = 1,
  int configVersion = 1,
  int decimalPlaces = 3,
  String title = 'Synthetic arithmetic fixture — not agricultural advice',
  String rate = '12.5',
}) => {
  'id': id,
  'ruleKey': 'synthetic-test-only',
  'version': version,
  'title': title,
  'crop': 'MAIZE',
  'fertilizer': {
    'slug': 'synthetic-product',
    'name': 'Synthetic product — test only',
  },
  'rateKgPerHectare': rate,
  'applicability': 'Synthetic arithmetic fixture only; not a recommendation.',
  'assumptions': [
    'Synthetic fixture applicability is intentionally not agronomic.',
  ],
  'source': {
    'title': 'Synthetic calculation fixture',
    'publisher': 'Automated tests only',
    'url': 'https://example.test/synthetic-fixture',
    'citation': 'Synthetic fixture; not authoritative agricultural guidance.',
  },
  'config': {
    'key': 'maize-area-rate',
    'version': configVersion,
    'engineVersion': 'area-rate-v1',
    'quantityDecimalPlaces': decimalPlaces,
    'roundingMode': 'HALF_UP',
  },
};

Map<String, Object?> catalogueJson({
  bool pending = false,
  List<Map<String, Object?>>? items,
}) => {
  'status': pending ? 'PENDING_RULES' : 'READY',
  'message': pending
      ? 'Project-approved fertilizer recommendations are pending.'
      : 'Synthetic fixture catalogue for automated tests only.',
  'engineVersion': 'area-rate-v1',
  'items': pending ? <Object?>[] : items ?? [ruleJson()],
};

FertilizerCatalogue catalogue({
  bool pending = false,
  List<Map<String, Object?>>? items,
}) =>
    FertilizerCatalogue.fromJson(catalogueJson(pending: pending, items: items));

FertilizerInput fixtureInput({
  String area = '2',
  FertilizerAreaUnit areaUnit = FertilizerAreaUnit.hectare,
  FertilizerMassUnit outputUnit = FertilizerMassUnit.kg,
  String ruleId = fixtureRuleId,
  int ruleVersion = 1,
  int configVersion = 1,
}) => FertilizerInput(
  area: area,
  areaUnit: areaUnit,
  outputUnit: outputUnit,
  ruleId: ruleId,
  ruleVersion: ruleVersion,
  configVersion: configVersion,
);

Map<String, Object?> resultJson({
  FertilizerInput? input,
  String quantity = '25.000',
  String unrounded = '25',
  String normalizedArea = '2',
  int decimalPlaces = 3,
  Map<String, Object?>? rule,
}) {
  final request = input ?? fixtureInput();
  return {
    'input': request.toJson(),
    'normalizedArea': {'value': normalizedArea, 'unit': 'HECTARE'},
    'quantity': {
      'value': quantity,
      'unit': request.outputUnit.wireValue,
      'unroundedValue': unrounded,
    },
    'rounding': {'mode': 'HALF_UP', 'decimalPlaces': decimalPlaces},
    'rule':
        rule ??
        ruleJson(
          id: request.ruleId,
          version: request.ruleVersion,
          configVersion: request.configVersion,
          decimalPlaces: decimalPlaces,
        ),
    'engineVersion': 'area-rate-v1',
    'explanation':
        'Synthetic arithmetic fixture: area multiplied by a test rate.',
    'assumptions': [
      'The selected synthetic test rate is not a recommendation.',
      'All unit conversions and calculations occur on the server.',
    ],
    'unitReference': {
      'title':
          'Synthetic reference metadata; unit arithmetic is tested on the server.',
      'url': 'https://example.test/synthetic-unit-reference',
    },
  };
}

FertilizerResult fertilizerResult({FertilizerInput? input}) =>
    FertilizerResult.fromJson(resultJson(input: input));

class FakeFertilizerRepository implements FertilizerRepository {
  FakeFertilizerRepository({this.pending = false});
  bool pending;
  int ruleCalls = 0;
  final inputs = <FertilizerInput>[];
  final catalogues = <Future<FertilizerCatalogue>>[];
  final calculations = <Future<FertilizerResult>>[];

  @override
  Future<FertilizerCatalogue> rules() {
    ruleCalls++;
    return catalogues.isNotEmpty
        ? catalogues.removeAt(0)
        : Future.value(catalogue(pending: pending));
  }

  @override
  Future<FertilizerResult> calculate(FertilizerInput input) {
    inputs.add(input);
    return calculations.isNotEmpty
        ? calculations.removeAt(0)
        : Future.value(fertilizerResult(input: input));
  }
}
