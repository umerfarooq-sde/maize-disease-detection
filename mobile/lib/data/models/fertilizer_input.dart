import '../../core/exceptions/app_exception.dart';
import 'calculator_input.dart';

typedef FertilizerAreaUnit = CalculatorAreaUnit;

enum FertilizerMassUnit {
  kg('KG', 'kg'),
  grams('G', 'g');

  const FertilizerMassUnit(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

/// Decimal text is preserved for the server's deterministic engine. This client
/// validates syntax; it never computes fertilizer quantities or converts area.
String normalizeFertilizerArea(String value) => normalizeCalculatorArea(value);

class FertilizerInput {
  FertilizerInput({
    required String area,
    required this.areaUnit,
    required this.ruleId,
    required this.ruleVersion,
    required this.configVersion,
    required this.outputUnit,
  }) : area = normalizeFertilizerArea(area) {
    if (!_uuid.hasMatch(ruleId) ||
        ruleVersion < 1 ||
        ruleVersion > 2147483647 ||
        configVersion < 1 ||
        configVersion > 2147483647) {
      throw const AppException(AppErrorKind.validation);
    }
  }

  final String area;
  final FertilizerAreaUnit areaUnit;
  final String ruleId;
  final int ruleVersion;
  final int configVersion;
  final FertilizerMassUnit outputUnit;

  Map<String, Object?> toJson() => {
    'area': area,
    'areaUnit': areaUnit.wireValue,
    'ruleId': ruleId,
    'ruleVersion': ruleVersion,
    'configVersion': configVersion,
    'outputUnit': outputUnit.wireValue,
  };

  static final _uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
}
