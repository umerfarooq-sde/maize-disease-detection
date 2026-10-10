import '../../core/exceptions/app_exception.dart';

enum ScanPredictionStatus { confident, lowConfidence }

enum ScanUncertaintyReason { thresholdUnconfigured, belowValidationThreshold }

class ScanPrediction {
  const ScanPrediction({
    required this.predictedClass,
    required this.confidence,
    required this.probabilities,
    required this.modelVersion,
    required this.preprocessingVersion,
    required this.predictionStatus,
    required this.uncertaintyReason,
    required this.confidenceThreshold,
    required this.inferenceDurationMs,
    required this.inferredAt,
  });

  static const classLabels = [
    'Common_Rust',
    'Gray_Leaf_Spot',
    'Healthy',
    'Northern_Corn_Leaf_Blight',
  ];

  final String predictedClass;
  final double confidence;
  final Map<String, double> probabilities;
  final String modelVersion;
  final String preprocessingVersion;
  final ScanPredictionStatus predictionStatus;
  final ScanUncertaintyReason? uncertaintyReason;
  final double? confidenceThreshold;
  final double inferenceDurationMs;
  final DateTime inferredAt;

  factory ScanPrediction.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final label = value['predictedClass'];
    final confidence = _probability(value['confidence']);
    final rawProbabilities = value['probabilities'];
    final modelVersion = value['modelVersion'];
    final preprocessingVersion = value['preprocessingVersion'];
    final duration = value['inferenceDurationMs'];
    final inferredAt = value['inferredAt'] is String
        ? DateTime.tryParse(value['inferredAt'] as String)
        : null;
    final status = switch (value['predictionStatus']) {
      'CONFIDENT' => ScanPredictionStatus.confident,
      'LOW_CONFIDENCE' => ScanPredictionStatus.lowConfidence,
      _ => null,
    };
    final reason = switch (value['uncertaintyReason']) {
      'THRESHOLD_UNCONFIGURED' => ScanUncertaintyReason.thresholdUnconfigured,
      'BELOW_VALIDATION_THRESHOLD' =>
        ScanUncertaintyReason.belowValidationThreshold,
      _ => null,
    };
    final rawThreshold = value['confidenceThreshold'];
    final threshold = _probability(rawThreshold);
    if (!classLabels.contains(label) ||
        !value.containsKey('uncertaintyReason') ||
        !value.containsKey('confidenceThreshold') ||
        confidence == null ||
        rawProbabilities is! Map<String, dynamic> ||
        rawProbabilities.length != classLabels.length ||
        !classLabels.every(rawProbabilities.containsKey) ||
        !_validVersion(modelVersion) ||
        !_validVersion(preprocessingVersion) ||
        duration is! num ||
        !duration.isFinite ||
        duration < 0 ||
        duration > 20000 ||
        inferredAt == null ||
        status == null ||
        (value['uncertaintyReason'] != null && reason == null) ||
        (rawThreshold != null &&
            (threshold == null || threshold <= 0 || threshold >= 1))) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final probabilities = <String, double>{};
    for (final entry in rawProbabilities.entries) {
      final probability = _probability(entry.value);
      if (probability == null) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      probabilities[entry.key] = probability;
    }
    final total = probabilities.values.fold(0.0, (sum, item) => sum + item);
    final coherentProbabilities =
        (total - 1).abs() <= 1e-5 &&
        (probabilities[label]! - confidence).abs() <= 1e-6 &&
        probabilities.values.every((item) => item <= confidence + 1e-6);
    final coherentUncertainty = threshold == null
        ? status == ScanPredictionStatus.lowConfidence &&
              reason == ScanUncertaintyReason.thresholdUnconfigured
        : confidence < threshold
        ? status == ScanPredictionStatus.lowConfidence &&
              reason == ScanUncertaintyReason.belowValidationThreshold
        : status == ScanPredictionStatus.confident && reason == null;
    if (!coherentProbabilities || !coherentUncertainty) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return ScanPrediction(
      predictedClass: label as String,
      confidence: confidence,
      probabilities: Map.unmodifiable(probabilities),
      modelVersion: modelVersion as String,
      preprocessingVersion: preprocessingVersion as String,
      predictionStatus: status,
      uncertaintyReason: reason,
      confidenceThreshold: threshold,
      inferenceDurationMs: duration.toDouble(),
      inferredAt: inferredAt,
    );
  }

  static double? _probability(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 1
      ? value.toDouble()
      : null;

  static bool _validVersion(Object? value) =>
      value is String &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value);
}
