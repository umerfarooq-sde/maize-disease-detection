import '../../core/exceptions/app_exception.dart';

enum FertilizerAreaUnit {
  hectare('HECTARE', 'Hectares'),
  acre('ACRE', 'Acres');

  const FertilizerAreaUnit(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

enum FertilizerMassUnit {
  kg('KG', 'kg'),
  grams('G', 'g');

  const FertilizerMassUnit(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

/// Decimal text is preserved for the server's deterministic engine. This client
/// validates syntax; it never computes fertilizer quantities or converts area.
String normalizeFertilizerArea(String value) {
  final normalized = value.trim();
  if (normalized.length > 24 ||
      !RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,6})?$').hasMatch(normalized) ||
      BigInt.parse(normalized.replaceAll('.', '')) == BigInt.zero ||
      _exceedsMaximum(normalized)) {
    throw const AppException(AppErrorKind.validation);
  }
  return normalized;
}

bool _exceedsMaximum(String area) {
  final parts = area.split('.');
  final whole = BigInt.parse(parts.first);
  return whole > BigInt.from(1000000) ||
      (whole == BigInt.from(1000000) &&
          parts.length > 1 &&
          BigInt.parse(parts.last) > BigInt.zero);
}

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
