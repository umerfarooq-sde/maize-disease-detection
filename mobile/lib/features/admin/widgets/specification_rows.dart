import 'dart:convert';

const specificationUnits = [
  'HECTARE',
  'KG',
  'GRAM',
  'TONNE',
  'KG_PER_HECTARE',
  'MG_PER_KG',
  'PERCENT',
  'COUNT',
  'DIMENSIONLESS',
];
List<String> specificationRowKeys(bool coefficients) => coefficients
    ? ['key', 'value', 'unit', 'sourceSection']
    : ['key', 'unit', 'description'];

/// Unknown structures stay in Advanced JSON; viewing never rewrites their text.
List<Map<String, String>>? structuredSpecificationRows(
  String raw, {
  required bool coefficients,
}) {
  try {
    final value = jsonDecode(raw);
    final keys = specificationRowKeys(coefficients);
    if (value is! List || value.length > (coefficients ? 32 : 16)) return null;
    final rows = <Map<String, String>>[];
    for (final row in value) {
      if (row is! Map ||
          row.length != keys.length ||
          !keys.every((key) => row[key] is String) ||
          !specificationUnits.contains(row['unit'])) {
        return null;
      }
      rows.add({for (final key in keys) key: row[key] as String});
    }
    return rows;
  } catch (_) {
    return null;
  }
}

String? validateSpecificationRows(
  String raw, {
  required bool coefficients,
  List<String> requiredOutputs = const [],
}) {
  Object? value;
  try {
    value = jsonDecode(raw);
  } catch (_) {
    return 'Enter a valid JSON array.';
  }
  if (value is! List) return 'Use a JSON array, not an object.';
  final max = coefficients ? 32 : 16;
  if (value.length > max || (!coefficients && value.isEmpty)) {
    return 'Use ${coefficients ? 0 : 1}–$max definitions.';
  }
  final keys = <String>{};
  for (final row in value) {
    if (row is! Map) return 'Each definition must be an object.';
    final key = row['key'];
    if (key is! String || !RegExp(r'^[a-z][a-z0-9_]{0,47}$').hasMatch(key)) {
      return 'Keys need 1–48 lowercase letters, digits or underscores, starting with a letter.';
    }
    if (!keys.add(key)) return 'Keys must be unique within this array.';
    if (!specificationUnits.contains(row['unit'])) {
      return 'Choose a supported unit.';
    }
    final detail = row[coefficients ? 'sourceSection' : 'description'];
    if (detail is! String ||
        detail.trim().isEmpty ||
        detail.trim().length > 600 ||
        detail.contains('\u0000')) {
      return 'Each description/source section needs 1–600 characters without null characters.';
    }
    if (coefficients) {
      final coefficient = row['value'];
      if (coefficient is! String ||
          coefficient.length > 64 ||
          !RegExp(
            r'^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$',
          ).hasMatch(coefficient)) {
        return 'Coefficient values must be signed decimal strings, up to 64 characters. No exponents or numeric JSON values.';
      }
    }
  }
  if (!requiredOutputs.every(keys.contains)) {
    return 'Required output keys: ${requiredOutputs.join(', ')}.';
  }
  return null;
}
