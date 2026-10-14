import 'dart:async';
import 'package:maizedoctor/data/models/yield_models.dart';
import 'package:maizedoctor/data/repositories/yield_repository.dart';

const fixtureId = '00000000-0000-4000-8000-000000000001';
Map<String, Object?> configurationJson({
  String id = fixtureId,
  int version = 1,
}) => {
  'id': id,
  'configKey': 'maize-area-yield',
  'version': version,
  'title': 'Synthetic arithmetic fixture only',
  'crop': 'MAIZE',
  'expectedYieldKgPerHectare': '12.5',
  'applicability': 'Synthetic testing; no field applicability.',
  'assumptions': ['Synthetic arithmetic values; not agricultural advice.'],
  'source': {
    'title': 'Synthetic source fixture',
    'publisher': 'Test suite',
    'url': 'https://example.invalid/synthetic-yield',
    'citation': 'No authoritative yield data.',
  },
  'engineVersion': yieldEngineVersion,
  'formulaVersion': yieldFormulaVersion,
  'rounding': {'mode': 'HALF_UP', 'decimalPlaces': 3},
};
Map<String, Object?> catalogueJson({
  bool pending = false,
  List<Object?>? items,
}) => {
  'status': pending ? 'PENDING_CONFIGURATION' : 'READY',
  'message': pending
      ? 'Authoritative model and rates pending.'
      : 'Synthetic fixture only.',
  'engineVersion': yieldEngineVersion,
  'items': items ?? (pending ? [] : [configurationJson()]),
};
YieldInput fixtureInput({
  String area = '2',
  CalculatorAreaUnit areaUnit = CalculatorAreaUnit.hectare,
  YieldMassUnit outputUnit = YieldMassUnit.kg,
  String configId = fixtureId,
  int version = 1,
}) => YieldInput(
  area: area,
  areaUnit: areaUnit,
  outputUnit: outputUnit,
  configId: configId,
  configVersion: version,
);
Map<String, Object?> resultJson({
  YieldInput? input,
  String value = '25.000',
  String unrounded = '25',
  Map<String, Object?>? configuration,
}) => {
  'input': (input ?? fixtureInput()).toJson(),
  'normalizedArea': {'value': '2', 'unit': 'HECTARE'},
  'expectedYield': {
    'value': value,
    'unit': (input ?? fixtureInput()).outputUnit.wireValue,
    'unroundedValue': unrounded,
  },
  'configuration': configuration ?? configurationJson(),
  'rounding': {'mode': 'HALF_UP', 'decimalPlaces': 3},
  'engineVersion': yieldEngineVersion,
  'formulaVersion': yieldFormulaVersion,
  'explanation':
      'Synthetic deterministic arithmetic. Actual harvest may differ.',
  'assumptions': ['Fixture only; no weather or soil adjustment is inferred.'],
  'unitReference': {
    'title': 'NIST Handbook 44 (2026), Appendix C',
    'url':
        'https://www.nist.gov/system/files/documents/2025/12/30/appc-26-HB44-20251222.pdf',
  },
};

class FakeYieldRepository implements YieldRepository {
  Future<YieldCatalogue> Function()? onConfigurations;
  Future<YieldResult> Function(YieldInput)? onCalculate;
  int reads = 0;
  final requests = <YieldInput>[];
  @override
  Future<YieldCatalogue> configurations() async {
    reads++;
    return onConfigurations != null
        ? onConfigurations!()
        : YieldCatalogue.fromJson(catalogueJson());
  }

  @override
  Future<YieldResult> calculate(YieldInput input) async {
    requests.add(input);
    return onCalculate != null
        ? onCalculate!(input)
        : YieldResult.fromJson(resultJson(input: input));
  }
}
