import '../../core/exceptions/app_exception.dart';

enum CalculatorAreaUnit {
  hectare('HECTARE', 'Hectares'),
  acre('ACRE', 'Acres');

  const CalculatorAreaUnit(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

String normalizeCalculatorArea(String value) =>
    normalizeCalculatorDecimal(value);

String normalizeCalculatorDecimal(String value, {bool allowZero = false}) {
  final normalized = value.trim();
  if (normalized.length > 24 ||
      !RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,6})?$').hasMatch(normalized) ||
      (!allowZero &&
          BigInt.parse(normalized.replaceAll('.', '')) == BigInt.zero) ||
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
