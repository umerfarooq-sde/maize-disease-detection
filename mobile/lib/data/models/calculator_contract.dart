import '../../core/exceptions/app_exception.dart';

// These helpers validate the calculator wire contract only. Calculated quantities
// and all unit conversions remain exclusively in the backend engine.
Map<String, dynamic> calculatorObject(Object? value, Set<String> fields) {
  if (value is! Map<String, dynamic> ||
      value.length != fields.length ||
      !fields.every(value.containsKey)) {
    throw invalidCalculatorResponse();
  }
  return value;
}

String calculatorText(Object? value, int maximum) {
  if (value is! String ||
      value.length > maximum ||
      value.trim().isEmpty ||
      value.contains('\u0000')) {
    throw invalidCalculatorResponse();
  }
  return value;
}

String calculatorPattern(Object? value, int maximum, String pattern) {
  final text = calculatorText(value, maximum);
  if (!RegExp(pattern).hasMatch(text)) throw invalidCalculatorResponse();
  return text;
}

int calculatorInteger(
  Object? value, {
  int minimum = 1,
  int maximum = 2147483647,
}) {
  if (value is! int || value < minimum || value > maximum) {
    throw invalidCalculatorResponse();
  }
  return value;
}

List<dynamic> calculatorList(Object? value, int maximum) {
  if (value is! List<dynamic> || value.length > maximum) {
    throw invalidCalculatorResponse();
  }
  return value;
}

Uri calculatorHttpsUrl(Object? value) {
  final text = calculatorText(value, 2048);
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      text.codeUnits.any((unit) => unit <= 32 || unit == 127)) {
    throw invalidCalculatorResponse();
  }
  return uri;
}

String calculatorDecimal(Object? value, {int maximumDecimalPlaces = 24}) =>
    calculatorPattern(
      value,
      80,
      '^(?:0|[1-9][0-9]*)(?:\\.[0-9]{1,$maximumDecimalPlaces})?\$',
    );

AppException invalidCalculatorResponse() =>
    const AppException(AppErrorKind.invalidResponse);

class CalculatorSource {
  const CalculatorSource._(this.title, this.publisher, this.url, this.citation);
  final String title;
  final String publisher;
  final Uri url;
  final String citation;
  factory CalculatorSource.fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'title',
      'publisher',
      'url',
      'citation',
    });
    return CalculatorSource._(
      calculatorText(data['title'], 255),
      calculatorText(data['publisher'], 255),
      calculatorHttpsUrl(data['url']),
      calculatorText(data['citation'], 1000),
    );
  }
}
