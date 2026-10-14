import '../../core/exceptions/app_exception.dart';

// These helpers validate the calculator wire contract only. Fertilizer quantities
// and all unit conversions remain exclusively in the backend engine.
Map<String, dynamic> fertilizerObject(Object? value, Set<String> fields) {
  if (value is! Map<String, dynamic> ||
      value.length != fields.length ||
      !fields.every(value.containsKey)) {
    throw invalidFertilizerResponse();
  }
  return value;
}

String fertilizerText(Object? value, int maximum) {
  if (value is! String ||
      value.length > maximum ||
      value.trim().isEmpty ||
      value.contains('\u0000')) {
    throw invalidFertilizerResponse();
  }
  return value;
}

String fertilizerPattern(Object? value, int maximum, String pattern) {
  final text = fertilizerText(value, maximum);
  if (!RegExp(pattern).hasMatch(text)) throw invalidFertilizerResponse();
  return text;
}

int fertilizerInteger(
  Object? value, {
  int minimum = 1,
  int maximum = 2147483647,
}) {
  if (value is! int || value < minimum || value > maximum) {
    throw invalidFertilizerResponse();
  }
  return value;
}

List<dynamic> fertilizerList(Object? value, int maximum) {
  if (value is! List<dynamic> || value.length > maximum) {
    throw invalidFertilizerResponse();
  }
  return value;
}

Uri fertilizerHttpsUrl(Object? value) {
  final text = fertilizerText(value, 2048);
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      text.codeUnits.any((unit) => unit <= 32 || unit == 127)) {
    throw invalidFertilizerResponse();
  }
  return uri;
}

String fertilizerDecimal(Object? value, {int maximumDecimalPlaces = 24}) =>
    fertilizerPattern(
      value,
      80,
      '^(?:0|[1-9][0-9]*)(?:\\.[0-9]{1,$maximumDecimalPlaces})?\$',
    );

AppException invalidFertilizerResponse() =>
    const AppException(AppErrorKind.invalidResponse);
